import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/utils/geo_utils.dart';
import '../../../../core/utils/registration_utils.dart';
import '../../../../data/repositories/attendance_repository.dart';
import '../../../../data/repositories/tracking_repository.dart';
import '../models/attendance_roster.dart';
import '../widgets/attendance_card.dart';
import '../widgets/attendance_stats_chips.dart';
import '../widgets/location_status_card.dart';
import '../widgets/no_trip_view.dart';
import '../widgets/trip_ended_view.dart';
import '../widgets/warning_banner.dart';

class ConductorAttendanceScreen extends ConsumerStatefulWidget {
  const ConductorAttendanceScreen({super.key});

  @override
  ConsumerState<ConductorAttendanceScreen> createState() =>
      _ConductorAttendanceScreenState();
}

class _ConductorAttendanceScreenState
    extends ConsumerState<ConductorAttendanceScreen> {
  // Conductor / bus info
  String _busId = '';
  String _routeId = '';
  String _conductorCredId = ''; // staff_credentials.id (not auth_user_id)

  // Trip state
  Map<String, dynamic>? _trip;
  List<Map<String, dynamic>> _stops = []; // ordered by stop_order
  List<AttendanceEntry> _attendances = [];

  String _searchQuery = '';
  AttendanceState? _filterState;
  bool _loading = true;
  bool _processing = false;
  bool _scanning = false;

  StreamSubscription<Position>? _locationSub;
  int _lastAdvancedIdx = -1; // prevents re-triggering the same stop
  DateTime? _lastGpsTime; // for GPS-loss detection
  Timer? _gpsWatchdog;
  bool _gpsLost = false;
  bool _offRoute = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _gpsWatchdog?.cancel();
    super.dispose();
  }

  // ─── Data loading ────────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cred = await ref
          .read(trackingRepositoryProvider)
          .conductorBusInfo();

      _conductorCredId = cred['id'] as String;
      _busId = cred['bus_id'] as String;
      _routeId = (cred['buses'] as Map)['route_id'] as String;

      _stops =
          (await ref.read(trackingRepositoryProvider).stopsForRoute(_routeId))
            ..sort(
              (a, b) =>
                  (a['stop_order'] as num).compareTo(b['stop_order'] as num),
            );

      _trip = await ref
          .read(attendanceRepositoryProvider)
          .currentOrLastTrip(busId: _busId, conductorId: _conductorCredId);

      if (_trip != null) {
        await _loadAttendances();
        _lastAdvancedIdx = (_trip!['current_stop_index'] as num).toInt();
        _startGpsTracking();
      }

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('[ATTENDANCE] load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadAttendances() async {
    if (_trip == null) return;

    final data = await ref
        .read(attendanceRepositoryProvider)
        .attendanceForTrip(_trip!['id'] as String);

    final currentStopIdx = (_trip!['current_stop_index'] as num).toInt();
    final currentStopOrder = currentStopIdx < _stops.length
        ? (_stops[currentStopIdx]['stop_order'] as num).toInt()
        : 0;

    final items = (data as List).map((r) {
      final busStop = r['bus_stops'] as Map?;
      final passenger = r['passengers'] as Map?;
      final stopOrder = (busStop?['stop_order'] as num?)?.toInt() ?? 0;
      return AttendanceEntry(
        id: r['id'] as String,
        passengerId: r['passenger_id'] as String,
        name: passenger?['name'] as String? ?? 'Unknown',
        stopId: r['stop_id'] as String,
        stopName: busStop?['name'] as String? ?? '?',
        stopOrder: stopOrder,
        state: AttendanceStateX.fromName(r['state'] as String),
        scannedAt: r['scanned_at'] != null
            ? DateTime.parse(r['scanned_at'] as String)
            : null,
      );
    }).toList();

    // Current stop first, then upcoming, then past
    AttendanceMachine.sortByCurrentStop(items, currentStopOrder);

    if (mounted) setState(() => _attendances = items);
  }

  // ─── Trip management ─────────────────────────────────────────────────────────

  Future<void> _startTrip() async {
    setState(() => _processing = true);
    try {
      final attendance = ref.read(attendanceRepositoryProvider);

      _trip = await attendance.startTrip(
        busId: _busId,
        conductorId: _conductorCredId,
      );

      final roster = await attendance.approvedRoster(_busId);
      await attendance.createAttendanceRecords(
        _trip!['id'] as String,
        roster,
        _busId,
      );

      _lastAdvancedIdx = 0;
      _startGpsTracking();
      await _loadAttendances();
    } catch (e) {
      debugPrint('[ATTENDANCE] start trip error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(friendlyError(e, fallback: 'Failed to start trip.')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ─── GPS tracking ─────────────────────────────────────────────────────────────

  void _startGpsTracking() async {
    await _locationSub?.cancel();
    _gpsWatchdog?.cancel();

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      return;
    }

    _lastGpsTime = DateTime.now();

    // Watchdog: flag GPS as lost if no update for 10 seconds
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_lastGpsTime!);
      final lost = elapsed.inSeconds > 10;
      if (lost != _gpsLost) setState(() => _gpsLost = lost);
    });

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
      ),
    ).listen(_onPosition);
  }

  void _onPosition(Position pos) {
    // Reset watchdog timestamp on every GPS update
    _lastGpsTime = DateTime.now();
    if (_gpsLost && mounted) setState(() => _gpsLost = false);

    if (_trip == null || _stops.isEmpty) return;

    // Check if bus is off the designated route
    final offRoute = _isOffRoute(pos.latitude, pos.longitude);
    if (offRoute != _offRoute && mounted) setState(() => _offRoute = offRoute);
    if (offRoute) return; // don't auto-advance while off-route

    // Find nearest stop with valid coordinates
    int nearestIdx = -1;
    double minDist = double.infinity;
    for (int i = 0; i < _stops.length; i++) {
      final lat = (_stops[i]['latitude'] as num?)?.toDouble() ?? 0;
      final lng = (_stops[i]['longitude'] as num?)?.toDouble() ?? 0;
      if (lat == 0 && lng == 0) continue;
      final d = haversineKm(pos.latitude, pos.longitude, lat, lng);
      if (d < minDist) {
        minDist = d;
        nearestIdx = i;
      }
    }

    final current = (_trip!['current_stop_index'] as num).toInt();
    if (nearestIdx <= current || nearestIdx <= _lastAdvancedIdx) return;
    if (minDist >= 0.3) return;

    // Guard against traffic-light false advances:
    // Only auto-advance if the bus is actually moving (>5 km/h)
    // OR within 50m (definitively at the stop even if briefly stopped).
    final speedKmh = (pos.speed * 3.6).clamp(0.0, double.infinity);
    final atStop = minDist < 0.05;
    final moving = speedKmh > 5.0;
    if (!atStop && !moving) return;

    _advanceTo(nearestIdx);
  }

  /// Whether the bus is farther than 200 m from every stop and from every
  /// straight segment between consecutive stops (i.e. off the route corridor).
  bool _isOffRoute(double lat, double lng) {
    const thresholdKm = 0.2;

    // 1. Check distance to each stop
    for (final stop in _stops) {
      final slat = (stop['latitude'] as num?)?.toDouble() ?? 0;
      final slng = (stop['longitude'] as num?)?.toDouble() ?? 0;
      if (slat == 0 && slng == 0) continue;
      if (haversineKm(lat, lng, slat, slng) < thresholdKm) return false;
    }

    // 2. Check distance to each segment between consecutive stops
    for (int i = 0; i < _stops.length - 1; i++) {
      final aLat = (_stops[i]['latitude'] as num?)?.toDouble() ?? 0;
      final aLng = (_stops[i]['longitude'] as num?)?.toDouble() ?? 0;
      final bLat = (_stops[i + 1]['latitude'] as num?)?.toDouble() ?? 0;
      final bLng = (_stops[i + 1]['longitude'] as num?)?.toDouble() ?? 0;
      if (aLat == 0 && aLng == 0) continue;
      if (bLat == 0 && bLng == 0) continue;
      if (pointToSegmentKm(lat, lng, aLat, aLng, bLat, bLng) < thresholdKm) {
        return false;
      }
    }

    return true; // nowhere near the route corridor
  }

  Future<void> _advanceTo(int newIdx) async {
    if (_trip == null || _processing) return;
    setState(() => _processing = true);
    try {
      final tripId = _trip!['id'] as String;
      final current = (_trip!['current_stop_index'] as num).toInt();
      final attendance = ref.read(attendanceRepositoryProvider);

      // Mark waiting passengers at all stops being passed as missing
      for (int i = current; i < newIdx; i++) {
        await attendance.markStopWaitingMissing(
          tripId,
          _stops[i]['id'] as String,
        );
        AttendanceMachine.markStopWaitingMissing(
          _attendances,
          _stops[i]['id'] as String,
        );
      }

      await attendance.updateCurrentStopIndex(tripId, newIdx);

      _trip!['current_stop_index'] = newIdx;
      _lastAdvancedIdx = newIdx;
      await _loadAttendances();
    } catch (e) {
      debugPrint('[ATTENDANCE] advance error: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _confirmEndTrip() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Trip'),
        content: const Text(
          'All remaining waiting passengers will be marked absent. End the trip?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endTrip();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('End Trip'),
          ),
        ],
      ),
    );
  }

  Future<void> _manualNextStop() async {
    if (_trip == null) return;
    final currentIdx = (_trip!['current_stop_index'] as num).toInt();
    if (currentIdx >= _stops.length - 1) {
      _confirmEndTrip();
      return;
    }
    final next = _stops[currentIdx + 1]['name'] as String;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Advance to next stop?'),
        content: Text(
          'Mark all waiting passengers at the current stop as missing and move to $next?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Advance'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _advanceTo(currentIdx + 1);
  }

  Future<void> _endTrip() async {
    if (_trip == null) return;
    setState(() => _processing = true);
    try {
      await ref
          .read(attendanceRepositoryProvider)
          .endTrip(_trip!['id'] as String);
      AttendanceMachine.markRemainingAbsent(_attendances);

      _trip!['state'] = 'ended';
      await _loadAttendances();
    } catch (e) {
      debugPrint('[ATTENDANCE] end trip error: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  // ─── OCR scan ────────────────────────────────────────────────────────────────

  Future<void> _scanId() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (picked == null) return;

      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(
        InputImage.fromFilePath(picked.path),
      );
      await recognizer.close();

      debugPrint('[OCR] text: ${result.text}');

      final rawText = result.text.trim();

      // No text detected at all — card not in frame or image too dark/blurry
      if (rawText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No text detected. Ensure the ID card fills the frame and the lighting is adequate.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Text found but no VIT registration number pattern
      final regNumber = extractRegNumber(rawText);

      if (regNumber == null) {
        debugPrint('[OCR] text found but no reg number: $rawText');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Text detected but no registration number found. '
                'Hold the card flat and steady, and try again.',
              ),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      await _markPresent(regNumber);
    } catch (e) {
      debugPrint('[ATTENDANCE] scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera error. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _markPresent(String regNumber) async {
    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final passenger = await attendanceRepo.findPassengerAnywhere(regNumber);

    if (passenger == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$regNumber — no account found with this registration number.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final name = passenger['name'] as String;
    final pid = passenger['id'] as String;
    final passengerBusId = passenger['bus_id'] as String?;
    final busInfo = passenger['buses'] as Map?;
    final busNumber = busInfo?['bus_number'] as String?;

    if (passengerBusId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name is not enrolled in any bus.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    if (passengerBusId != _busId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$name belongs to Bus ${busNumber ?? passengerBusId}.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      return;
    }

    final record = _attendances.where((a) => a.passengerId == pid).firstOrNull;

    if (record == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name has no record for this trip')),
        );
      }
      return;
    }

    if (record.state == AttendanceState.present) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name is already marked present')),
        );
      }
      return;
    }

    // Warn conductor before overriding a student whose stop was already passed
    if (record.state == AttendanceState.missing && mounted) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stop already passed'),
          content: Text(
            '$name was marked missing — their stop (${record.stopName}) '
            'has already been passed. Mark them present anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark Present'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await attendanceRepo.markPresent(record.id);
    AttendanceMachine.markPresent(_attendances, record.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $name marked present'),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    await _loadAttendances();
  }

  /// Manually mark a passenger as present (for faculty or when scan fails).
  Future<void> _manualMarkPresent(AttendanceEntry item) async {
    final name = item.name;
    final stopName = item.stopName;

    if (item.state == AttendanceState.missing) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stop already passed'),
          content: Text(
            '$name was marked missing — their stop ($stopName) '
            'has already been passed. Mark them present anyway?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark Present'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      await ref.read(attendanceRepositoryProvider).markPresent(item.id);
      AttendanceMachine.markPresent(_attendances, item.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ $name marked present'),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await _loadAttendances();
    } catch (e) {
      debugPrint('[ATTENDANCE] mark present error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to mark present'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOngoing = _trip?['state'] == 'ongoing';

    return Scaffold(
      appBar: AppBar(
        title: Text(S.t(context, 'Attendance')),
        centerTitle: false,
        scrolledUnderElevation: 0,
        actions: [
          if (isOngoing)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 12, 8),
              child: TextButton(
                onPressed: _processing ? null : _confirmEndTrip,
                style: TextButton.styleFrom(
                  backgroundColor: theme.colorScheme.error.withValues(
                    alpha: 0.10,
                  ),
                  foregroundColor: theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                child: Text(S.t(context, 'End Trip')),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: LottieLoading())
          : _trip == null
          ? NoTripView(processing: _processing, onStart: _startTrip)
          : _trip!['state'] == 'ended'
          ? TripEndedView(
              stats: _stats(),
              onNewTrip: () => setState(() {
                _trip = null;
                _attendances = [];
              }),
            )
          : _buildAttendanceView(theme),
      // OCR (ML Kit) is mobile-only — hide the scan action on web.
      floatingActionButton: (isOngoing && !kIsWeb)
          ? FloatingActionButton.extended(
              heroTag: 'conductor_attendance_fab',
              backgroundColor: const Color(0xFF3D3D8F),
              onPressed: _scanning ? null : _scanId,
              icon: _scanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : SvgPicture.asset(
                      'assets/icons/qr-scan.svg',
                      width: 22,
                      height: 22,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
              label: Text(S.t(context, 'Scan ID')),
            )
          : null,
    );
  }

  // ─── Sub-views ───────────────────────────────────────────────────────────────





  Widget _buildAttendanceView(ThemeData theme) {
    final currentIdx = (_trip!['current_stop_index'] as num).toInt();
    final currentStop = currentIdx < _stops.length ? _stops[currentIdx] : null;
    final isLastStop = currentIdx >= _stops.length - 1;
    final isDark = theme.brightness == Brightness.dark;
    final showNextStop =
        _trip!['state'] == 'ongoing' &&
        (_trip!['current_stop_index'] as num).toInt() < _stops.length - 1;
    final s = _stats();

    final filtered = _attendances.where((a) {
      final matchesState = _filterState == null || a.state == _filterState;
      final matchesSearch =
          _searchQuery.isEmpty ||
          a.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesState && matchesSearch;
    }).toList();

    return Column(
      children: [
        // ── Warning banners ────────────────────────────────────────────────
        if (_gpsLost)
          WarningBanner(
            icon: Icons.gps_off_rounded,
            message: S.t(context, 'GPS lost — auto-advance paused.'),
            showNextStop: showNextStop,
            processing: _processing,
            onNextStop: _manualNextStop,
          ),
        if (_offRoute && !_gpsLost)
          WarningBanner(
            icon: Icons.map_outlined,
            message: S.t(context, 'Bus is off the designated route.'),
            showNextStop: showNextStop,
            processing: _processing,
            onNextStop: _manualNextStop,
          ),

        // ── Current location card ──────────────────────────────────────────
        LocationStatusCard(
          gpsLost: _gpsLost,
          offRoute: _offRoute,
          stopName: currentStop?['name'] as String?,
          isLastStop: isLastStop,
        ),

        // ── Stats chips ────────────────────────────────────────────────────
        AttendanceStatsChips(
          total: _attendances.length,
          stats: s,
          selected: _filterState,
          onSelected: (v) => setState(() => _filterState = v),
        ),

        // ── Search ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: S.t(context, 'Search'),
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.6,
                ),
                fontSize: 14,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(13),
                child: SvgPicture.asset(
                  'assets/icons/search.svg',
                  width: 18,
                  height: 18,
                  colorFilter: ColorFilter.mode(
                    theme.colorScheme.onSurfaceVariant,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              filled: true,
              fillColor: isDark
                  ? theme.colorScheme.surfaceContainerHigh
                  : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        // ── List ───────────────────────────────────────────────────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAttendances,
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      S.t(context, 'No results'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => AttendanceCard(
                        entry: filtered[i],
                        onTap: () => _manualMarkPresent(filtered[i]),
                      ),
                  ),
          ),
        ),
      ],
    );
  }




  Map<String, int> _stats() => AttendanceMachine.stats(_attendances);
}
