import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/l10n/strings.dart';
import '../../../../data/repositories/attendance_repository.dart';
import '../../../../data/repositories/tracking_repository.dart';

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
  List<_AttendanceItem> _attendances = [];

  String _searchQuery = '';
  String? _filterState;
  bool _loading = true;
  bool _processing = false;
  bool _scanning = false;

  StreamSubscription<Position>? _locationSub;
  int _lastAdvancedIdx = -1; // prevents re-triggering the same stop
  DateTime? _lastGpsTime;   // for GPS-loss detection
  Timer? _gpsWatchdog;
  bool _gpsLost = false;

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
      final cred = await ref.read(trackingRepositoryProvider).conductorBusInfo();

      _conductorCredId = cred['id'] as String;
      _busId = cred['bus_id'] as String;
      _routeId = (cred['buses'] as Map)['route_id'] as String;

      _stops = (await ref
          .read(trackingRepositoryProvider)
          .stopsForRoute(_routeId))
        ..sort((a, b) => (a['stop_order'] as num).compareTo(b['stop_order'] as num));

      _trip = await ref.read(attendanceRepositoryProvider).currentOrLastTrip(
            busId: _busId,
            conductorId: _conductorCredId,
          );

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
      return _AttendanceItem(
        id: r['id'] as String,
        passengerId: r['passenger_id'] as String,
        name: passenger?['name'] as String? ?? 'Unknown',
        stopId: r['stop_id'] as String,
        stopName: busStop?['name'] as String? ?? '?',
        stopOrder: stopOrder,
        state: r['state'] as String,
        scannedAt: r['scanned_at'] != null
            ? DateTime.parse(r['scanned_at'] as String)
            : null,
      );
    }).toList();

    // Current stop first, then upcoming, then past
    items.sort((a, b) {
      if (a.stopOrder == currentStopOrder &&
          b.stopOrder != currentStopOrder) {
        return -1;
      }
      if (a.stopOrder != currentStopOrder &&
          b.stopOrder == currentStopOrder) {
        return 1;
      }
      return a.stopOrder.compareTo(b.stopOrder);
    });

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
      await attendance.createAttendanceRecords(_trip!['id'] as String, roster);

      _lastAdvancedIdx = 0;
      _startGpsTracking();
      await _loadAttendances();
    } catch (e) {
      debugPrint('[ATTENDANCE] start trip error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to start trip: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
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

    // Watchdog: flag GPS as lost if no update for 30 seconds
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(_lastGpsTime!);
      final lost = elapsed.inSeconds > 30;
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

    // Find nearest stop with valid coordinates
    int nearestIdx = -1;
    double minDist = double.infinity;
    for (int i = 0; i < _stops.length; i++) {
      final lat = (_stops[i]['latitude']  as num?)?.toDouble() ?? 0;
      final lng = (_stops[i]['longitude'] as num?)?.toDouble() ?? 0;
      if (lat == 0 && lng == 0) continue;
      final d = _haversineKm(pos.latitude, pos.longitude, lat, lng);
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
    final atStop   = minDist < 0.05;
    final moving   = speedKmh > 5.0;
    if (!atStop && !moving) return;

    _advanceTo(nearestIdx);
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
            tripId, _stops[i]['id'] as String);
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

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLng = (lng2 - lng1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  void _confirmEndTrip() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Trip'),
        content: const Text(
            'All remaining waiting passengers will be marked absent. End the trip?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _endTrip();
            },
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
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
        content: Text('Mark all waiting passengers at the current stop as missing and move to $next?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Advance')),
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
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.camera, imageQuality: 90);
      if (picked == null) return;

      final recognizer =
          TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer
          .processImage(InputImage.fromFilePath(picked.path));
      await recognizer.close();

      debugPrint('[OCR] text: ${result.text}');

      final rawText = result.text.trim();

      // No text detected at all — card not in frame or image too dark/blurry
      if (rawText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'No text detected. Ensure the ID card fills the frame and the lighting is adequate.'),
            duration: Duration(seconds: 3),
          ));
        }
        return;
      }

      // Text found but no VIT registration number pattern
      final match = RegExp(r'\b\d{2}[A-Z]{3}\d{5}\b')
          .firstMatch(rawText.toUpperCase());

      if (match == null) {
        debugPrint('[OCR] text found but no reg number: $rawText');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Text detected but no registration number found. '
                'Hold the card flat and steady, and try again.'),
            duration: Duration(seconds: 3),
          ));
        }
        return;
      }

      await _markPresent(match.group(0)!);
    } catch (e) {
      debugPrint('[ATTENDANCE] scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Camera error. Please try again.'),
          duration: Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _markPresent(String regNumber) async {
    final passenger = await ref
        .read(attendanceRepositoryProvider)
        .findPassengerByReg(regNumber, _busId);

    if (passenger == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$regNumber — not found on this bus'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
      return;
    }

    final name = passenger['name'] as String;
    final pid = passenger['id'] as String;

    final record =
        _attendances.where((a) => a.passengerId == pid).firstOrNull;

    if (record == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name has no record for this trip')));
      }
      return;
    }

    if (record.state == 'present') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$name is already marked present')));
      }
      return;
    }

    // Warn conductor before overriding a student whose stop was already passed
    if (record.state == 'missing' && mounted) {
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
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Mark Present')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await ref.read(attendanceRepositoryProvider).markPresent(record.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✓ $name marked present'),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 2),
      ));
    }

    await _loadAttendances();
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
                  backgroundColor:
                      theme.colorScheme.error.withValues(alpha: 0.10),
                  foregroundColor: theme.colorScheme.error,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                child: Text(S.t(context, 'End Trip')),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: LottieLoading())
          : _trip == null
              ? _buildNoTrip(theme)
              : _trip!['state'] == 'ended'
                  ? _buildTripEnded(theme)
                  : _buildAttendanceView(theme),
      floatingActionButton: isOngoing
          ? FloatingActionButton.extended(
              heroTag: 'conductor_attendance_fab',
              backgroundColor: const Color(0xFF3D3D8F),
              onPressed: _scanning ? null : _scanId,
              icon: _scanning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : SvgPicture.asset('assets/icons/qr-scan.svg', width: 22, height: 22, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
              label: Text(S.t(context, 'Scan ID')),
            )
          : null,
    );
  }

  // ─── Sub-views ───────────────────────────────────────────────────────────────

  Widget _buildNoTrip(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1A2580), const Color(0xFF0D1560)]
                      : [const Color(0xFF3D5AFE), const Color(0xFF3D3D8F)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3D5AFE).withValues(alpha: 0.3),
                    blurRadius: 16, offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset('assets/icons/bus.svg',
                    width: 36, height: 36,
                    colorFilter: const ColorFilter.mode(
                        Colors.white, BlendMode.srcIn)),
              ),
            ),
            const SizedBox(height: 24),
            Text(S.t(context, 'No Active Trip'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(S.t(context, 'Start a trip to begin taking attendance'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _processing ? null : _startTrip,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              icon: _processing
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(S.t(context, 'Start Trip'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripEnded(ThemeData theme) {
    final s = _stats();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.green.shade200, width: 2),
              ),
              child: Icon(Icons.check_rounded,
                  size: 52, color: Colors.green.shade600),
            ),
            const SizedBox(height: 20),
            Text(S.t(context, 'Trip Complete'),
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            // Summary chips
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _summaryPill('${s['present']}', S.t(context, 'Present'), Colors.green.shade700, Colors.green.shade50),
                const SizedBox(width: 8),
                _summaryPill('${s['missing']}', S.t(context, 'Missed'), Colors.purple.shade400, Colors.purple.shade50),
                const SizedBox(width: 8),
                _summaryPill('${s['absent']}', S.t(context, 'Absent'), Colors.red.shade600, Colors.red.shade50),
              ],
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => setState(() { _trip = null; _attendances = []; }),
              icon: const Icon(Icons.restart_alt_rounded),
              label: Text(S.t(context, 'New Trip')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryPill(String count, String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(count, style: TextStyle(
            color: textColor, fontSize: 20, fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(
            color: textColor, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAttendanceView(ThemeData theme) {
    final currentIdx = (_trip!['current_stop_index'] as num).toInt();
    final currentStop = currentIdx < _stops.length ? _stops[currentIdx] : null;
    final isLastStop = currentIdx >= _stops.length - 1;
    final isDark = theme.brightness == Brightness.dark;
    final showNextStop = _trip!['state'] == 'ongoing' &&
        (_trip!['current_stop_index'] as num).toInt() < _stops.length - 1;
    final s = _stats();

    final filtered = _attendances.where((a) {
      final matchesState = _filterState == null || a.state == _filterState;
      final matchesSearch = _searchQuery.isEmpty ||
          a.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesState && matchesSearch;
    }).toList();

    return Column(
      children: [
        // ── GPS lost banner ────────────────────────────────────────────────
        if (_gpsLost)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade800
                  .withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: Colors.amber.shade700.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(Icons.gps_off_rounded,
                    size: 18,
                    color: isDark
                        ? Colors.amber.shade300
                        : Colors.amber.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.t(context, 'GPS lost — auto-advance paused.'),
                    style: TextStyle(
                      color: isDark
                          ? Colors.amber.shade200
                          : Colors.amber.shade900,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (showNextStop) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _processing ? null : _manualNextStop,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    child: Text(S.t(context, 'Next Stop →')),
                  ),
                ],
              ],
            ),
          ),

        // ── Current location card ──────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHigh
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color:
                    theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: isDark ? 0.15 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: (_gpsLost
                          ? Colors.amber.shade700
                          : theme.colorScheme.primary)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _gpsLost
                      ? Icons.gps_off_rounded
                      : Icons.location_on_rounded,
                  size: 18,
                  color: _gpsLost
                      ? Colors.amber.shade700
                      : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.t(context, 'Current Location:'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentStop?['name'] as String? ?? 'Starting',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isLastStop)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    S.t(context, 'Final Stop'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // ── Stats chips ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 6, 8),
          child: Row(
            children: [
              _statChip(S.t(context, 'Total'), _attendances.length,
                  null, null, theme),
              _statChip(S.t(context, 'Present'), s['present']!,
                  Colors.green.shade700, 'present', theme),
              _statChip(S.t(context, 'Missed'), s['missing']!,
                  Colors.purple.shade400, 'missing', theme),
              _statChip(S.t(context, 'Absent'), s['absent']!,
                  theme.colorScheme.error, 'absent', theme),
              _statChip(S.t(context, 'Waiting'), s['waiting']!,
                  Colors.amber.shade700, 'waiting', theme),
            ],
          ),
        ),

        // ── Search ─────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: S.t(context, 'Search'),
              hintStyle: TextStyle(
                color: theme.colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.6),
                fontSize: 14,
              ),
              prefixIcon: Padding(
                padding: const EdgeInsets.all(13),
                child: SvgPicture.asset('assets/icons/search.svg',
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(
                        theme.colorScheme.onSurfaceVariant,
                        BlendMode.srcIn)),
              ),
              filled: true,
              fillColor: isDark
                  ? theme.colorScheme.surfaceContainerHigh
                  : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                    color: theme.colorScheme.primary, width: 1.5),
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
                    child: Text(S.t(context, 'No results'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _buildCard(filtered[i], theme),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _statChip(
      String label, int count, Color? color, String? filterValue,
      ThemeData theme) {
    final isSelected = _filterState == filterValue;
    final isDark = theme.brightness == Brightness.dark;
    final chipColor = color ?? theme.colorScheme.primary;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: isSelected
                ? chipColor
                : (isDark
                    ? theme.colorScheme.surfaceContainerHigh
                    : Colors.white),
            borderRadius: BorderRadius.circular(12),
            border: isSelected
                ? null
                : Border.all(
                    color: theme.colorScheme.outlineVariant, width: 1),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: chipColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: isDark ? 0.15 : 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(
                  () => _filterState = isSelected ? null : filterValue),
              splashColor: isSelected
                  ? Colors.white.withValues(alpha: 0.2)
                  : chipColor.withValues(alpha: 0.1),
              highlightColor: isSelected
                  ? Colors.white.withValues(alpha: 0.1)
                  : chipColor.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.85)
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : chipColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(_AttendanceItem item, ThemeData theme) {
    final color = _stateColor(item.state);
    final isDark = theme.brightness == Brightness.dark;
    final stateLabel = switch (item.state) {
      'present' => S.t(context, 'Present'),
      'missing' => S.t(context, 'Missed'),
      'absent'  => S.t(context, 'Absent'),
      _         => S.t(context, 'Waiting'),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        splashColor: color.withValues(alpha: 0.06),
        highlightColor: color.withValues(alpha: 0.03),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHigh
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar with initial
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    item.name.isNotEmpty
                        ? item.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Name + Stop
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.stopName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: color.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Text(
                  stateLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _stateColor(String state) => switch (state) {
        'present' => Colors.green.shade700,
        'missing' => Colors.purple.shade400,
        'absent' => Colors.red.shade700,
        _ => Colors.amber.shade700,
      };

  Map<String, int> _stats() => {
        'present':
            _attendances.where((a) => a.state == 'present').length,
        'missing':
            _attendances.where((a) => a.state == 'missing').length,
        'absent':
            _attendances.where((a) => a.state == 'absent').length,
        'waiting':
            _attendances.where((a) => a.state == 'waiting').length,
      };
}

// ─── Model ────────────────────────────────────────────────────────────────────

class _AttendanceItem {
  final String id;
  final String passengerId;
  final String name;
  final String stopId;
  final String stopName;
  final int stopOrder;
  String state;
  DateTime? scannedAt;

  _AttendanceItem({
    required this.id,
    required this.passengerId,
    required this.name,
    required this.stopId,
    required this.stopName,
    required this.stopOrder,
    required this.state,
    this.scannedAt,
  });
}
