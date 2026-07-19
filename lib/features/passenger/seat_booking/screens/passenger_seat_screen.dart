import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../data/models/seat_reservation.dart';
import '../../../../data/repositories/seat_repository.dart';
import '../../../../data/repositories/seat_reservation_repository.dart';
import '../../../../main.dart';
import '../widgets/booking_history_sheet.dart';

class PassengerSeatScreen extends ConsumerStatefulWidget {
  const PassengerSeatScreen({super.key});

  @override
  ConsumerState<PassengerSeatScreen> createState() => _PassengerSeatScreenState();
}

class _PassengerSeatScreenState extends ConsumerState<PassengerSeatScreen> {
  // Bus / user info
  String _busNumber = '';
  String _busId = '';
  String _userType = 'student';
  int _leftSeats = 0;               // total physical left-column seats
  int _studentCount = 0;            // total right + back seats
  int _facultyRowsLeft = 0;         // top N left rows = yellow
  int _facultyRowsRight = 0;        // top N right rows = yellow

  // Seat state
  List<_SeatInfo> _seats = [];
  int? _selectedSeat;
  int? _confirmedSeat;
  bool _editing = false;

  bool _loading = true;
  bool _submitting = false;
  bool _showLegend = false;

  // Reservation state
  SeatReservation? _reservation;      // approved active reservation
  SeatReservation? _pendingReservation; // pending reservation request
  bool _reservingSeat = false;

  RealtimeChannel? _busConfigChannel;

  // ─── Booking window ────────────────────────────────────────────────────────

  static const _openHour  = 20; // 8 PM — opens for next day
  static const _closeHour = 19; // 7 PM — locks for current day

  _BookingState get _bookingState {
    if (AppConfig.demoMode) return _BookingState.open; // always open for the demo
    final h = DateTime.now().hour;
    if (h >= _closeHour && h < _openHour) return _BookingState.locked;
    return _BookingState.open;
  }

  Duration get _timeUntilNextEvent {
    final now = DateTime.now();
    final h   = now.hour;
    final DateTime target;
    if (h >= _closeHour && h < _openHour) {
      target = DateTime(now.year, now.month, now.day, _openHour);
    } else if (h < _closeHour) {
      target = DateTime(now.year, now.month, now.day, _closeHour);
    } else {
      target = DateTime(now.year, now.month, now.day + 1, _closeHour);
    }
    return target.difference(now);
  }

  DateTime get _bookingDate {
    final now = DateTime.now();
    if (now.hour >= _openHour) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    return DateTime(now.year, now.month, now.day);
  }

  String get _bookingDateStr => _bookingDate.toIso8601String().substring(0, 10);

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _busConfigChannel?.unsubscribe();
    super.dispose();
  }

  // ─── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final profile = await ref.read(seatRepositoryProvider).seatBusInfo();

      _busId      = profile['bus_id']    as String;
      _userType   = profile['user_type'] as String;
      final bus   = profile['buses']     as Map;

      _busNumber       = bus['bus_number']                as String;
      _leftSeats       = (bus['left_seats']               as num).toInt();
      _studentCount    = (bus['student_seats']            as num).toInt();
      _facultyRowsLeft = (bus['faculty_reserved_rows_left']  as num).toInt();
      _facultyRowsRight= (bus['faculty_reserved_rows_right'] as num).toInt();

      debugPrint('[PASS_SEAT] Initial load: busId=$_busId '
          'facultyRowsLeft=$_facultyRowsLeft facultyRowsRight=$_facultyRowsRight');

      await _loadBookings(ref.read(seatRepositoryProvider).currentUserId);
      _subscribeBusConfig();
    } catch (e) {
      debugPrint('[PASS_SEAT] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeBusConfig() {
    _busConfigChannel?.unsubscribe();
    _busConfigChannel = supabase
        .channel('bus_config_$_busId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.buses,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _busId,
          ),
          callback: (payload) => _onBusConfigChanged(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> _onBusConfigChanged(Map<String, dynamic> newData) async {
    if (!mounted) return;

    final newLeft = (newData['faculty_reserved_rows_left'] as num?)?.toInt();
    final newRight = (newData['faculty_reserved_rows_right'] as num?)?.toInt();
    debugPrint('[PASS_SEAT] Realtime bus config changed: '
        'newLeft=$newLeft newRight=$newRight '
        'currentLeft=$_facultyRowsLeft currentRight=$_facultyRowsRight');
    if (newLeft == null || newRight == null) return;
    if (newLeft == _facultyRowsLeft && newRight == _facultyRowsRight) return;

    _facultyRowsLeft = newLeft;
    _facultyRowsRight = newRight;

    final seatRepo = ref.read(seatRepositoryProvider);
    final userId = seatRepo.currentUserId;

    // Rebuild seat list with the new faculty-row layout
    final seats = _buildSeats();

    // If the user's confirmed seat was reclassified to a type they can't book,
    // auto-clear the orphaned booking and notify them.
    if (_confirmedSeat != null) {
      final idx = seats.indexWhere((s) => s.number == _confirmedSeat);
      if (idx != -1) {
        final seat = seats[idx];
        final orphaned =
            (_userType == 'student' && seat.type == _SeatType.faculty) ||
            (_userType == 'faculty' && seat.type == _SeatType.student);

        if (orphaned) {
          try {
            await seatRepo.clearMyBooking(_bookingDateStr);
          } catch (_) {}
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_userType == 'student'
                  ? 'Your seat is now reserved for faculty. Please choose a student seat.'
                  : 'Your seat is now a student seat. Please choose a faculty seat.'),
              backgroundColor: Colors.orange.shade700,
            ));
          }
        }
      }
    }

    // Reload bookings so taken-seat markers reflect the DB state.
    await _loadBookings(userId);
  }

  Future<void> _loadBookings(String userId) async {
    final seatRepo = ref.read(seatRepositoryProvider);
    final resRepo  = ref.read(seatReservationRepositoryProvider);
    final bookings = await seatRepo.bookingsForDate(_busId, _bookingDateStr);

    // Load active + pending reservations
    final activeReservations =
        await resRepo.activeReservationsForBus(_busId);
    final myReservation   = await resRepo.myActiveReservation();
    final myPending       = await resRepo.myPendingReservation();

    final seats = _buildSeats();
    int? confirmed;

    // Mark daily bookings
    for (final b in bookings as List) {
      final seatNum = b['seat_number'] as int;
      final pid     = b['passenger_id'] as String;
      final name    = (b['passengers'] as Map?)?['name'] as String? ?? 'Unknown';

      final idx = seats.indexWhere((s) => s.number == seatNum);
      if (idx == -1) continue;
      seats[idx].bookedBy    = name;
      seats[idx].isMyBooking = pid == userId;
      if (pid == userId) confirmed = seatNum;
    }

    // Mark permanently reserved seats (overrides daily booking for other users
    // if the daily booking was made before the reservation).
    for (final entry in activeReservations.entries) {
      final seatNum = entry.key;
      final idx = seats.indexWhere((s) => s.number == seatNum);
      if (idx == -1) continue;
      seats[idx].isReserved = true;
      if (!seats[idx].isMyBooking) {
        seats[idx].bookedBy = entry.value;
      }
    }

    // If the current user has an approved reservation, auto-select it.
    int? reservedSeat;
    if (myReservation != null) {
      reservedSeat = myReservation.seatNumber;
      // Auto-book the reserved seat if not already booked for today
      if (confirmed == null) {
        try {
          await seatRepo.clearMyBooking(_bookingDateStr);
          await seatRepo.bookSeat(
            busId: _busId,
            seatNumber: reservedSeat,
            dateStr: _bookingDateStr,
          );
          confirmed = reservedSeat;
          final idx = seats.indexWhere((s) => s.number == reservedSeat);
          if (idx != -1) {
            seats[idx].isMyBooking = true;
            seats[idx].bookedBy = null;
          }
        } catch (e) {
          debugPrint('[PASS_SEAT] auto-book reserved seat failed: $e');
        }
      }
    }

    if (mounted) {
      setState(() {
        _seats              = seats;
        _confirmedSeat      = confirmed;
        _selectedSeat       = confirmed;
        _reservation        = myReservation;
        _pendingReservation = myPending;
        _loading            = false;
      });
    }
  }

  // Seat numbering:
  //   1 … _leftSeats              → left column (L1…)
  //   _leftSeats+1 … +rightCount  → right column (R1…)
  //   last backCount              → back row (B1…)
  //
  // Colour:
  //   Left  row ≤ _facultyRowsLeft  → faculty (yellow)
  //   Right row ≤ _facultyRowsRight → faculty (yellow)
  //   everything else               → student (red)
  List<_SeatInfo> _buildSeats() {
    final seats = <_SeatInfo>[];

    // Left column — 2 seats per row
    final facultyLeftSeats = _facultyRowsLeft * 2;
    for (int i = 1; i <= _leftSeats; i++) {
      seats.add(_SeatInfo(
        number: i,
        label:  'L$i',
        type:   i <= facultyLeftSeats ? _SeatType.faculty : _SeatType.student,
      ));
    }

    // Right column — 3 seats per row, last 6 = back row
    final backCount  = min(6, _studentCount);
    final rightCount = _studentCount - backCount;
    final facultyRightSeats = _facultyRowsRight * 3;

    for (int i = 1; i <= rightCount; i++) {
      seats.add(_SeatInfo(
        number: _leftSeats + i,
        label:  'R$i',
        type:   i <= facultyRightSeats ? _SeatType.faculty : _SeatType.student,
      ));
    }

    // Back row — always student
    for (int i = 1; i <= backCount; i++) {
      seats.add(_SeatInfo(
        number: _leftSeats + rightCount + i,
        label:  'B$i',
        type:   _SeatType.student,
      ));
    }

    return seats;
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  void _onSeatTap(_SeatInfo seat) {
    if (_bookingState != _BookingState.open) return;

    // Must tap Edit first when already booked
    if (_confirmedSeat != null && !_editing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tap "Edit" to change your seat'),
        duration: Duration(seconds: 2),
      ));
      return;
    }

    if (seat.bookedBy != null && !seat.isMyBooking) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Booked by ${seat.bookedBy}'),
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    final canBook =
        (_userType == 'faculty' && seat.type == _SeatType.faculty) ||
        (_userType == 'student' && seat.type == _SeatType.student);

    if (!canBook) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_userType == 'faculty'
            ? 'Faculty can only book yellow seats'
            : 'Students can only book red seats'),
        duration: const Duration(seconds: 2),
      ));
      return;
    }

    setState(() {
      _selectedSeat = _selectedSeat == seat.number ? null : seat.number;
    });
  }

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    final seatBeingBooked = _selectedSeat; // capture before _loadBookings resets state
    try {
      final seatRepo = ref.read(seatRepositoryProvider);
      final userId = seatRepo.currentUserId;

      await seatRepo.clearMyBooking(_bookingDateStr);

      if (_selectedSeat != null) {
        try {
          await seatRepo.bookSeat(
            busId: _busId,
            seatNumber: _selectedSeat!,
            dateStr: _bookingDateStr,
          );
        } on PostgrestException catch (e) {
          if (e.code == '23505') {
            await _loadBookings(userId);
            if (mounted) {
              setState(() => _selectedSeat = null);
              await showErrorOverlay(
                  context, 'That seat was just taken. Please choose another.');
            }
            return;
          }
          rethrow;
        }
      }

      await _loadBookings(userId);
      if (mounted) {
        setState(() => _editing = false);
        await showSuccessOverlay(
          context,
          message: seatBeingBooked != null ? 'Seat booked!' : null,
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('[SEAT] confirm error: ${e.message}');
      if (mounted) await showErrorOverlay(context, 'Booking failed: ${e.message}');
    } catch (e) {
      debugPrint('[SEAT] confirm error: $e');
      if (mounted) await showErrorOverlay(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _reserveSeat() async {
    if (_confirmedSeat == null || _submitting) return;
    setState(() => _reservingSeat = true);
    try {
      final resRepo = ref.read(seatReservationRepositoryProvider);
      await resRepo.createReservation(
        busId: _busId,
        passengerId: ref.read(seatRepositoryProvider).currentUserId,
        seatNumber: _confirmedSeat!,
      );
      final pending = await resRepo.myPendingReservation();
      if (mounted) {
        setState(() => _pendingReservation = pending);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
              'Reservation request sent to the conductor for approval.'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      debugPrint('[PASS_SEAT] reserve error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send reservation request.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _reservingSeat = false);
    }
  }

  Future<void> _cancelReservation() async {
    if (_reservation == null) return;
    setState(() => _submitting = true);
    try {
      final resRepo = ref.read(seatReservationRepositoryProvider);
      await resRepo.cancelReservation(_reservation!.id);
      final seatRepo = ref.read(seatRepositoryProvider);
      await _loadBookings(seatRepo.currentUserId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Reservation cancelled.'),
          backgroundColor: Colors.orange,
        ));
      }
    } catch (e) {
      debugPrint('[PASS_SEAT] cancel reservation error: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showBookingHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const BookingHistorySheet(),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_busNumber.isEmpty ? 'My Seat' : _busNumber),
        centerTitle: true,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            tooltip: _showLegend ? 'Hide legend' : 'Show legend',
            icon: Text('?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: _showLegend
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                )),
            onPressed: () => setState(() => _showLegend = !_showLegend),
          ),
          IconButton(
            tooltip: 'Booking history',
            icon: const Icon(Icons.history_rounded),
            onPressed: _showBookingHistory,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: LottieLoading())
          : Column(
              children: [
                _BookingStatusBar(
                  bookingState: _bookingState,
                  timeUntilNextEvent: _timeUntilNextEvent,
                  showLegend: _showLegend,
                  buildLegend: () => _buildLegend(theme),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: _buildBusLayout(theme),
                  ),
                ),
                _buildBottomBar(theme),
              ],
            ),
    );
  }


  static const _legendTileWidth = 120.0;

  Widget _buildLegend(ThemeData theme) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: _legendTileWidth,
              child: _legendTile(theme, _studentColor, 'Student'),
            ),
            SizedBox(
              width: _legendTileWidth,
              child: _legendTile(theme, _facultyColor, 'Faculty'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: _legendTileWidth,
              child: _legendTile(theme, theme.colorScheme.outline, 'Taken', isX: true),
            ),
            SizedBox(
              width: _legendTileWidth,
              child: _legendTile(theme, _facultyColor, 'Reserved', isStar: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _legendTile(ThemeData theme, Color color, String label,
      {bool isX = false, bool isStar = false}) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 1.5),
          ),
          child: isX
              ? Icon(Icons.close, size: 14, color: color)
              : isStar
                  ? Icon(Icons.star, size: 14, color: color)
                  : null,
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }

  static const _studentColor = Color(0xFFB71C1C); // deep red
  static const _facultyColor = Color(0xFFF9A825); // amber/gold

  // Each seat cell is 40 px tall; gap between rows is 8 px → row stride = 48 px.
  // The right column is offset down by half a stride (24 px) to match real bus layout.
  static const _rowStride = 48.0;
  static const _rightOffset = _rowStride / 2;

  Widget _buildBusLayout(ThemeData theme) {
    final leftSeats  = _seats.where((s) => s.label.startsWith('L')).toList();
    final rightSeats = _seats.where((s) => s.label.startsWith('R')).toList();
    final backSeats  = _seats.where((s) => s.label.startsWith('B')).toList();

    // Build left column widgets (pairs of 2).
    // The last pair (e.g. L17/L18) sits near the back door — add a gap before it.
    final leftRows = <List<_SeatInfo>>[];
    for (int i = 0; i < leftSeats.length; i += 2) {
      leftRows.add([
        leftSeats[i],
        if (i + 1 < leftSeats.length) leftSeats[i + 1],
      ]);
    }

    final leftWidgets = <Widget>[];
    for (int i = 0; i < leftRows.length; i++) {
      if (i == leftRows.length - 1 && leftRows.length > 2) {
        leftWidgets.add(const SizedBox(height: _rightOffset)); // back-door gap
      }
      leftWidgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSeat(leftRows[i][0], theme),
            const SizedBox(width: 8),
            if (leftRows[i].length > 1) _buildSeat(leftRows[i][1], theme),
          ],
        ),
      ));
    }

    // Build right column widgets (rows of 3)
    final rightWidgets = <Widget>[];
    for (int i = 0; i < rightSeats.length; i += 3) {
      final rowChildren = <Widget>[];
      for (int j = 0; j < 3 && i + j < rightSeats.length; j++) {
        if (rowChildren.isNotEmpty) rowChildren.add(const SizedBox(width: 8));
        rowChildren.add(_buildSeat(rightSeats[i + j], theme));
      }
      rightWidgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: rowChildren),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Main seating — left and right as independent columns, right offset ↓
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(children: leftWidgets),
            const SizedBox(width: 28), // aisle
            Padding(
              padding: const EdgeInsets.only(top: _rightOffset),
              child: Column(children: rightWidgets),
            ),
          ],
        ),
        // Back row
        if (backSeats.isNotEmpty) ...[
          const SizedBox(height: 4),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: backSeats
                .map((s) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: _buildSeat(s, theme),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSeat(_SeatInfo seat, ThemeData theme) {
    final isFaculty = seat.type == _SeatType.faculty;
    final baseColor = isFaculty ? _facultyColor : _studentColor;
    final isTaken   = seat.bookedBy != null && !seat.isMyBooking;
    final isSelected = _selectedSeat == seat.number;

    final Color borderColor;
    final Color bgColor;
    final Widget child;

    if (isTaken) {
      borderColor = theme.colorScheme.outline;
      bgColor     = theme.colorScheme.surfaceContainerHigh;
      child       = seat.isReserved
          ? Icon(Icons.star, size: 14, color: _facultyColor)
          : Icon(Icons.close, size: 14, color: theme.colorScheme.outline);
    } else if (isSelected) {
      borderColor = seat.isReserved ? _facultyColor : baseColor;
      bgColor     = seat.isReserved ? _facultyColor : baseColor;
      child = seat.isReserved
          ? Icon(Icons.star, size: 16, color: Colors.white)
          : Text(seat.label,
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white));
    } else {
      borderColor = baseColor;
      bgColor     = Colors.transparent;
      child       = Text(seat.label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w500, color: baseColor));
    }

    return GestureDetector(
      onTap: () => _onSeatTap(seat),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isSelected ? 3.0 : 2.2),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final isOpen  = _bookingState == _BookingState.open;
    final confirmedLabel = _confirmedSeat != null
        ? _seats.firstWhere((s) => s.number == _confirmedSeat!).label
        : 'None';
    final isFaculty = _userType == 'faculty';
    final canReserve = isFaculty && _confirmedSeat != null &&
        _reservation == null && _pendingReservation == null;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border:
              Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Row(
          children: [
            // Seat label + reservation status
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.titleMedium,
                    children: [
                      const TextSpan(
                          text: 'Seat: ',
                          style: TextStyle(fontWeight: FontWeight.w400)),
                      TextSpan(
                        text: confirmedLabel,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                if (_reservation != null)
                  Text('Permanently reserved',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: _facultyColor,
                          fontWeight: FontWeight.w600)),
                if (_pendingReservation != null)
                  Text('Reservation pending',
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600)),
              ],
            ),
            const Spacer(),
            // Reserve button (faculty only, after booking, no existing reservation)
            if (canReserve) ...[
              TextButton.icon(
                onPressed: _reservingSeat ? null : _reserveSeat,
                icon: _reservingSeat
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.star_border, size: 18),
                label: const Text('Reserve',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: _facultyColor,
                  minimumSize: const Size(90, 46),
                ),
              ),
              const SizedBox(width: 8),
            ],
            // Cancel reservation button (faculty only, has active reservation)
            if (isFaculty && _reservation != null) ...[
              TextButton.icon(
                onPressed: _submitting ? null : _cancelReservation,
                icon: const Icon(Icons.star, size: 18, color: _facultyColor),
                label: const Text('Unreserve',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange.shade700,
                  minimumSize: const Size(100, 46),
                ),
              ),
              const SizedBox(width: 8),
            ],
            _buildActionButton(theme, isOpen, isFaculty),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme, bool isOpen, bool isFaculty) {
    final hasBooking = _confirmedSeat != null;
    final showEdit = hasBooking && !_editing;
    final showConfirm =
        _selectedSeat != null && _selectedSeat != _confirmedSeat;
    final buttonLabel = showEdit
        ? 'Edit'
        : showConfirm
            ? 'Confirm'
            : _editing
                ? 'Cancel'
                : 'Confirm';
    final canPress = isOpen && !_submitting &&
        (showEdit || showConfirm || _editing);

    VoidCallback? onPressed;
    if (showEdit) {
      onPressed = () => setState(() => _editing = true);
    } else if (showConfirm) {
      onPressed = _confirm;
    } else if (_editing) {
      onPressed = () => setState(() => _editing = false);
    }

    return FilledButton(
      onPressed: canPress ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor:
            isOpen ? (isFaculty ? _facultyColor : _studentColor) : null,
        minimumSize: const Size(130, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _submitting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

enum _SeatType { faculty, student }

enum _BookingState { open, locked }

class _SeatInfo {
  final int number;
  final String label;
  final _SeatType type;
  String? bookedBy;
  bool isMyBooking = false;
  bool isReserved = false; // permanently reserved for someone

  _SeatInfo({
    required this.number,
    required this.label,
    required this.type,
  });
}

// ─── Isolated countdown widget ────────────────────────────────────────────────
// Owns its own Timer so only the status bar text rebuilds every second,
// not the entire seat layout.

class _BookingStatusBar extends StatefulWidget {
  final _BookingState bookingState;
  final Duration timeUntilNextEvent;
  final bool showLegend;
  final Widget Function() buildLegend;

  const _BookingStatusBar({
    required this.bookingState,
    required this.timeUntilNextEvent,
    required this.showLegend,
    required this.buildLegend,
  });

  @override
  State<_BookingStatusBar> createState() => _BookingStatusBarState();
}

class _BookingStatusBarState extends State<_BookingStatusBar> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeUntilNextEvent;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = _remaining.inSeconds > 0
            ? _remaining - const Duration(seconds: 1)
            : _recompute();
      });
    });
  }

  Duration _recompute() {
    final now = DateTime.now();
    final h = now.hour;
    if (h >= 19 && h < 20) {
      return DateTime(now.year, now.month, now.day, 20).difference(now);
    } else if (h < 19) {
      return DateTime(now.year, now.month, now.day, 19).difference(now);
    } else {
      return DateTime(now.year, now.month, now.day + 1, 19).difference(now);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _remaining;
    final durStr = '${d.inHours}h ${d.inMinutes % 60}m ${d.inSeconds % 60}s';
    final isLocked = widget.bookingState == _BookingState.locked;

    final message = isLocked
        ? 'Seat selection starts in $durStr'
        : 'Open — closes in $durStr';
    final color = isLocked
        ? theme.colorScheme.onSurfaceVariant
        : Colors.green.shade700;

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainerLow,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Text(message,
              style: theme.textTheme.bodySmall?.copyWith(color: color)),
          if (widget.showLegend) ...[
            const SizedBox(height: 10),
            widget.buildLegend(),
          ],
        ],
      ),
    );
  }
}
