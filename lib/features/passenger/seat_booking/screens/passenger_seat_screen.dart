import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../data/repositories/seat_repository.dart';
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

  bool _loading = true;
  bool _submitting = false;

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

      await _loadBookings(ref.read(seatRepositoryProvider).currentUserId);
    } catch (e) {
      debugPrint('[SEAT] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBookings(String userId) async {
    final bookings = await ref
        .read(seatRepositoryProvider)
        .bookingsForDate(_busId, _bookingDateStr);

    final seats = _buildSeats();
    int? confirmed;

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

    if (mounted) {
      setState(() {
        _seats         = seats;
        _confirmedSeat = confirmed;
        _selectedSeat  = confirmed;
        _loading       = false;
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


  Widget _buildLegend(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _legendTile(theme, _studentColor, 'Student'),
        const SizedBox(width: 20),
        _legendTile(theme, _facultyColor, 'Faculty'),
        const SizedBox(width: 20),
        _legendTile(theme, theme.colorScheme.outline, 'Taken', isX: true),
      ],
    );
  }

  Widget _legendTile(ThemeData theme, Color color, String label,
      {bool isX = false}) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color, width: 1.5),
          ),
          child: isX ? Icon(Icons.close, size: 14, color: color) : null,
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
      child       = Icon(Icons.close, size: 14, color: theme.colorScheme.outline);
    } else if (isSelected) {
      borderColor = baseColor;
      bgColor     = baseColor;
      child       = Text(seat.label,
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
    final hasChange = _selectedSeat != _confirmedSeat;
    final confirmedLabel = _confirmedSeat != null
        ? _seats.firstWhere((s) => s.number == _confirmedSeat!).label
        : 'None';

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
            const Spacer(),
            FilledButton(
              onPressed: (isOpen && hasChange && !_submitting) ? _confirm : null,
              style: FilledButton.styleFrom(
                backgroundColor: isOpen
                    ? (_userType == 'faculty' ? _facultyColor : _studentColor)
                    : null,
                minimumSize: const Size(130, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _selectedSeat != null ? 'Confirm' : 'Cancel Booking',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
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
  final Widget Function() buildLegend;

  const _BookingStatusBar({
    required this.bookingState,
    required this.timeUntilNextEvent,
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
          Text(message, style: theme.textTheme.bodySmall?.copyWith(color: color)),
          const SizedBox(height: 10),
          widget.buildLegend(),
        ],
      ),
    );
  }
}
