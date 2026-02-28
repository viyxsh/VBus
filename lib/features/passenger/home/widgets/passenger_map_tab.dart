import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../core/widgets/web_map_placeholder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/services/notification_service.dart';
import '../../../../../core/services/route_service.dart';
import '../../../../../core/utils/error_messages.dart';
import '../../../../../data/repositories/passenger_repository.dart';
import '../../../../../data/repositories/tracking_repository.dart';
import '../../profile/providers/passenger_profile_providers.dart';

class PassengerMapTab extends ConsumerStatefulWidget {
  const PassengerMapTab({super.key});

  @override
  ConsumerState<PassengerMapTab> createState() => _PassengerMapTabState();
}

class _PassengerMapTabState extends ConsumerState<PassengerMapTab> {
  GoogleMapController? _mapController;

  String _busId = '';
  String _busNumber = '';
  String _myStopId = '';
  List<Map<String, dynamic>> _stops = [];
  List<LatLng> _routePoints = [];
  bool _hasActiveTrip = false;
  String? _tripId; // current ongoing trip — used to reject stale bus_locations rows
  LatLng? _busLocation;
  int _busStopIndex = -1;

  // GPS-derived progress — keeps the bottom-sheet timeline in sync with the live
  // bus marker instead of relying solely on the trip's current_stop_index (which
  // only advances while the conductor is on the attendance screen).
  int _liveStopIndex = -1;          // stop the bus is at / heading toward
  bool _busAtStop = false;          // true when the bus is physically at _liveStopIndex
  bool _busOffRoute = false;        // true when the bus is far from the drawn route
  List<double> _stopDistAlong = []; // each stop's distance (km) along the route
  double _busAlongKm = 0;           // bus's distance (km) along the route

  static const double _kAtStopKm   = 0.25; // within this of a stop → "at" it
  static const double _kOffRouteKm = 2.0;  // farther than this from the route → off-route

  List<Map<String, dynamic>> _customPins = [];
  double _busSpeedKmh = 30.0;
  final Set<String> _notifiedPinIds = {};
  int _myStopIndex = -1;
  bool _stopArrivalNotified = false;
  StreamSubscription<List<Map<String, dynamic>>>? _tripSub;

  bool _loading = true;
  RealtimeChannel? _channel;

  BitmapDescriptor? _stopIcon;
  BitmapDescriptor? _myStopIcon;
  BitmapDescriptor? _busIcon;
  BitmapDescriptor? _pinIcon;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _tripSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ─── Custom marker builders ───────────────────────────────────────────────────

  Future<BitmapDescriptor> _circleMarkerIcon({
    required Color fill,
    required Color stroke,
    double size = 22,
    double strokeWidth = 2.5,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;
    canvas.drawCircle(Offset(r, r), r - strokeWidth / 2,
        Paint()..color = fill..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(r, r), r - strokeWidth / 2,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _busMarkerIconFromSvg(double size) async {
    final completer = Completer<BitmapDescriptor>();
    final key = GlobalKey();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10000, top: -10000,
        child: RepaintBoundary(
          key: key,
          child: _BusIconWidget(size: size),
        ),
      ),
    );

    Overlay.of(context).insert(entry);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final boundary = key.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
          if (boundary != null) {
            final img = await boundary.toImage(pixelRatio: 3.0);
            final data = await img.toByteData(format: ui.ImageByteFormat.png);
            completer.complete(
              data != null
                  ? BitmapDescriptor.bytes(
                      data.buffer.asUint8List(),
                      imagePixelRatio: 3.0,
                    )
                  : await _busMarkerIcon(size),
            );
          } else {
            completer.complete(await _busMarkerIcon(size));
          }
        } catch (e) {
          debugPrint('[PASSENGER_MAP] svg icon error: $e');
          completer.complete(await _busMarkerIcon(size));
        } finally {
          entry.remove();
        }
      });
    });

    return completer.future;
  }

  Future<BitmapDescriptor> _busMarkerIcon(double size) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final r = size / 2;
    canvas.drawCircle(Offset(r, r), r - 1.5,
        Paint()..color = const Color(0xFF3D3D8F)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(r, r), r - 1.5,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5);
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(Icons.directions_bus_rounded.codePoint),
      style: TextStyle(
        fontSize: size * 0.52,
        fontFamily: Icons.directions_bus_rounded.fontFamily,
        package: Icons.directions_bus_rounded.fontPackage,
        color: Colors.white,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _customPinMarkerIcon(double size) async {
    final recorder = ui.PictureRecorder();
    final canvas   = Canvas(recorder);
    final r        = size / 2;
    canvas.drawCircle(Offset(r, r), r - 1.5,
        Paint()..color = const Color(0xFFE65100)..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(r, r), r - 1.5,
        Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.5);
    final tp = TextPainter(textDirection: ui.TextDirection.ltr);
    tp.text = TextSpan(
      text: String.fromCharCode(Icons.location_on_rounded.codePoint),
      style: TextStyle(
        fontSize: size * 0.52,
        fontFamily: Icons.location_on_rounded.fontFamily,
        package: Icons.location_on_rounded.fontPackage,
        color: Colors.white,
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    final picture = recorder.endRecording();
    final image   = await picture.toImage(size.toInt(), size.toInt());
    final bytes   = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  // ─── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final tracking = ref.read(trackingRepositoryProvider);
      final profile = await tracking.passengerBusInfo();

      _busId    = profile['bus_id']  as String;
      _myStopId = profile['stop_id'] as String;
      final bus = profile['buses'] as Map;
      _busNumber = bus['bus_number'] as String;
      final routeId = bus['route_id'] as String;

      _stops = (await tracking.stopsForRoute(routeId))
        ..sort((a, b) => (a['stop_order'] as num).compareTo(b['stop_order'] as num));
      _myStopIndex = _stops.indexWhere((s) => s['id'] == _myStopId);
      debugPrint('[MAP] first stop: ${_stops.isNotEmpty ? _stops.first['name'] : 'none'}');
      _routePoints = await RouteService.getRoutePoints(_stops);
      _computeStopDistances();

      _stopIcon   = await _circleMarkerIcon(fill: Colors.white, stroke: const Color(0xFF37474F), size: 32);
      _myStopIcon = await _circleMarkerIcon(fill: Colors.green.shade600, stroke: Colors.white, size: 32, strokeWidth: 3);
      _pinIcon    = await _customPinMarkerIcon(32);
      final busIconFuture = _busMarkerIconFromSvg(32);

      final trip = await tracking.ongoingTripForBus(_busId);

      _hasActiveTrip = trip != null;
      if (_hasActiveTrip) {
        _tripId = trip!['id'] as String;
        _busStopIndex = (trip['current_stop_index'] as num).toInt();
        _subscribeToTrip(_tripId!);
        // Only accept bus_locations rows from THIS trip — anything else is
        // stale data from a previous trip (likely the conductor's home/test
        // location) and must not be shown.
        final loc = await tracking.busLocationForTrip(_busId, _tripId!);
        if (loc != null) {
          _busLocation  = LatLng(
            (loc['latitude']  as num).toDouble(),
            (loc['longitude'] as num).toDouble(),
          );
          _busSpeedKmh = (loc['speed_kmh'] as num?)?.toDouble() ?? 30.0;
        }
        _recomputeProgress();
        _subscribeToLocation();
      }

      // Load custom pins for this bus
      _customPins = await ref.read(passengerRepositoryProvider).customPins(_busId);

      _busIcon = await busIconFuture;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('[PASSENGER_MAP] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToLocation() {
    _channel = ref.read(trackingRepositoryProvider).subscribeBusLocations(
      busId: _busId,
      onRow: (r) {
        if (!mounted) return;
        // Reject updates from previous trips (stale conductor data)
        if (r['trip_id'] != _tripId) return;
        _busSpeedKmh = (r['speed_kmh'] as num?)?.toDouble() ?? _busSpeedKmh;
        _busLocation = LatLng(
          (r['latitude']  as num).toDouble(),
          (r['longitude'] as num).toDouble(),
        );
        _recomputeProgress();
        if (mounted) setState(() {});
        _checkPinProximity();
      },
    );
  }

  // ─── Custom pins ──────────────────────────────────────────────────────────────

  void _checkPinProximity() {
    if (_busLocation == null || _customPins.isEmpty) return;
    final speed = _busSpeedKmh > 2 ? _busSpeedKmh : 20.0;

    for (final pin in _customPins) {
      final id = pin['id'] as String;
      if (_notifiedPinIds.contains(id)) continue;

      final dist = _haversineKm(
        _busLocation!.latitude, _busLocation!.longitude,
        (pin['latitude']  as num).toDouble(),
        (pin['longitude'] as num).toDouble(),
      );
      final etaMins = (dist * 1.3) / speed * 60;
      final threshold = (pin['notify_minutes_before'] as num).toInt();

      if (etaMins <= threshold) {
        _notifiedPinIds.add(id);
        NotificationService.show(
          id: pin['id'].hashCode,
          title: 'Bus approaching ${pin['label']}',
          body: 'Approximately ${etaMins.round()} min away',
        );
        ref.read(passengerRepositoryProvider).markPinNotified(id);
      }
    }
  }

  void _subscribeToTrip(String tripId) {
    _tripSub = ref
        .read(trackingRepositoryProvider)
        .watchTrip(tripId)
        .listen((data) {
      if (data.isEmpty || !mounted) return;
      final newIdx = (data.first['current_stop_index'] as num).toInt();
      if (newIdx != _busStopIndex) {
        setState(() => _busStopIndex = newIdx);
        _checkStopArrival(newIdx);
      }
    });
  }

  void _checkStopArrival(int currentIdx) async {
    if (_stopArrivalNotified || _myStopIndex < 0) return;
    if (currentIdx != _myStopIndex) return;
    const storage = FlutterSecureStorage();
    final enabled = await storage.read(key: 'bus_arrival_notification');
    if (enabled != 'true') return;
    _stopArrivalNotified = true;
    NotificationService.show(
      id: 'stop_arrival'.hashCode,
      title: 'Bus arriving at your stop!',
      body: 'Bus $_busNumber is now at ${_stops[_myStopIndex]['name']}',
    );
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

  // ─── GPS-derived progress ───────────────────────────────────────────────────────

  // Precomputes how far along the route each stop sits, so live GPS can be
  // compared against stops on the same axis. Empty when the route is degenerate.
  void _computeStopDistances() {
    _stopDistAlong = [];
    if (_routePoints.length < 2) return;
    for (final s in _stops) {
      final lat = (s['latitude']  as num).toDouble();
      final lng = (s['longitude'] as num).toDouble();
      _stopDistAlong.add(
        (lat == 0 && lng == 0) ? 0 : _projectOntoRoute(LatLng(lat, lng))[0],
      );
    }
  }

  // Maps the live bus location onto the route to decide which stop it is at or
  // heading toward, and whether it has strayed off the route. Falls back to the
  // trip's current_stop_index (via _liveStopIndex = -1) when GPS or the route is
  // unavailable.
  void _recomputeProgress() {
    if (_busLocation == null ||
        _stops.isEmpty ||
        _stopDistAlong.length != _stops.length) {
      _liveStopIndex = -1;
      _busAtStop = false;
      _busOffRoute = false;
      return;
    }

    final proj    = _projectOntoRoute(_busLocation!);
    final alongKm = proj[0];
    _busAlongKm   = alongKm;
    _busOffRoute  = proj[1] > _kOffRouteKm;

    // Nearest stop by straight-line distance → "at stop" detection.
    int nearestIdx = 0;
    double nearestDist = double.infinity;
    for (int i = 0; i < _stops.length; i++) {
      final lat = (_stops[i]['latitude']  as num).toDouble();
      final lng = (_stops[i]['longitude'] as num).toDouble();
      if (lat == 0 && lng == 0) continue;
      final d = _haversineKm(
          _busLocation!.latitude, _busLocation!.longitude, lat, lng);
      if (d < nearestDist) { nearestDist = d; nearestIdx = i; }
    }

    if (nearestDist <= _kAtStopKm) {
      _busAtStop = true;
      _liveStopIndex = nearestIdx;
      _checkStopArrival(nearestIdx);
      return;
    }

    // In transit → current stop is the first one still ahead along the route.
    _busAtStop = false;
    int ahead = _stops.length - 1;
    for (int i = 0; i < _stops.length; i++) {
      if (_stopDistAlong[i] >= alongKm) { ahead = i; break; }
    }
    _liveStopIndex = ahead;
  }

  // A short, user-facing status for the bus relative to the passenger's own
  // stop: live ETA while en route, or an at/passed message. Null when there's
  // nothing reliable to show (no trip, no live GPS, off route, or no stop set).
  String? _myStopStatus() {
    if (!_hasActiveTrip || _busLocation == null || _busOffRoute) return null;
    if (_myStopIndex < 0 || _stopDistAlong.length != _stops.length) return null;

    // Already at the passenger's stop.
    if (_busAtStop && _liveStopIndex == _myStopIndex) {
      return 'Bus is at your stop';
    }

    final remainingKm = _stopDistAlong[_myStopIndex] - _busAlongKm;
    if (remainingKm <= 0.05) return 'Bus has passed your stop';

    // Floor the speed so a bus idling at a light doesn't report a huge ETA.
    final speed = _busSpeedKmh > 5 ? _busSpeedKmh : 18.0;
    final mins = (remainingKm / speed * 60).round();
    if (mins <= 1) return 'Arriving at your stop';
    return '~$mins min to your stop';
  }

  // Projects [p] onto the route polyline. Returns [alongKm, perpKm]: the distance
  // of the projection from the route start, and the perpendicular distance from
  // [p] to the nearest point on the route.
  List<double> _projectOntoRoute(LatLng p) {
    double bestPerp = double.infinity;
    double bestAlong = 0;
    double cumulative = 0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      final a = _routePoints[i];
      final b = _routePoints[i + 1];
      final seg = _segmentProjection(p, a, b);
      if (seg[1] < bestPerp) {
        bestPerp  = seg[1];
        bestAlong = cumulative + seg[0];
      }
      cumulative += _haversineKm(a.latitude, a.longitude, b.latitude, b.longitude);
    }
    return [bestAlong, bestPerp];
  }

  // Projects [p] onto segment [a]→[b] using a local planar approximation (good
  // enough at city scale). Returns [alongFromAKm, perpKm].
  List<double> _segmentProjection(LatLng p, LatLng a, LatLng b) {
    final kmPerDegLng = 111.32 * cos(a.latitude * pi / 180);
    const kmPerDegLat = 111.32;
    final bx = (b.longitude - a.longitude) * kmPerDegLng;
    final by = (b.latitude  - a.latitude)  * kmPerDegLat;
    final px = (p.longitude - a.longitude) * kmPerDegLng;
    final py = (p.latitude  - a.latitude)  * kmPerDegLat;
    final segLen2 = bx * bx + by * by;
    double t = segLen2 == 0 ? 0 : (px * bx + py * by) / segLen2;
    t = t.clamp(0.0, 1.0);
    final projx = bx * t, projy = by * t;
    final along = sqrt(projx * projx + projy * projy);
    final perp  = sqrt((px - projx) * (px - projx) + (py - projy) * (py - projy));
    return [along, perp];
  }

  Future<void> _addPin(LatLng position) async {
    final labelCtrl = TextEditingController();
    int threshold   = 5;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('Add Custom Pin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Label',
                  hintText: 'e.g. Near my colony gate',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: threshold,
                decoration: InputDecoration(
                  labelText: 'Notify me before',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                items: [2, 5, 10, 15]
                    .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text('$m minutes'),
                        ))
                    .toList(),
                onChanged: (v) => setSt(() => threshold = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Add Pin')),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    if (labelCtrl.text.trim().isEmpty) return;

    try {
      await ref.read(passengerRepositoryProvider).addCustomPin(
            busId: _busId,
            label: labelCtrl.text.trim(),
            latitude: position.latitude,
            longitude: position.longitude,
            notifyMinutesBefore: threshold,
          );

      if (mounted) ref.invalidate(customPinsProvider(_busId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(friendlyError(e, fallback: 'Failed to add pin.')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
  }

  Future<void> _deletePin(String id, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Pin'),
        content: Text('Remove "$label"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(passengerRepositoryProvider).deleteCustomPin(id);
    _notifiedPinIds.remove(id);
    if (mounted) ref.invalidate(customPinsProvider(_busId));
  }

  // ─── Map helpers ──────────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBounds();
  }

  void _centerOnBus() {
    if (_busLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _busLocation!, zoom: 15),
        ),
      );
    } else {
      _fitBounds();
    }
  }

  void _fitBounds() {
    final valid = _stops.where((s) =>
        (s['latitude'] as num).toDouble() != 0 &&
        (s['longitude'] as num).toDouble() != 0).toList();
    if (valid.isEmpty || _mapController == null) return;
    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    for (final s in valid) {
      final lat = (s['latitude']  as num).toDouble();
      final lng = (s['longitude'] as num).toDouble();
      minLat = min(minLat, lat); maxLat = max(maxLat, lat);
      minLng = min(minLng, lng); maxLng = max(maxLng, lng);
    }
    // Include the live bus position so an off-route bus is never left off-screen.
    if (_busLocation != null) {
      minLat = min(minLat, _busLocation!.latitude);
      maxLat = max(maxLat, _busLocation!.latitude);
      minLng = min(minLng, _busLocation!.longitude);
      maxLng = max(maxLng, _busLocation!.longitude);
    }
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      80,
    ));
  }

  Set<Marker> _buildMarkers() {
    if (_stopIcon == null) return {};
    final markers = <Marker>{};
    for (final s in _stops) {
      final lat = (s['latitude']  as num).toDouble();
      final lng = (s['longitude'] as num).toDouble();
      if (lat == 0 && lng == 0) continue;
      final isMyStop = s['id'] == _myStopId;
      markers.add(Marker(
        markerId: MarkerId(s['id'] as String),
        position: LatLng(lat, lng),
        icon: isMyStop ? _myStopIcon! : _stopIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: isMyStop ? 3 : 0,
        infoWindow: InfoWindow(title: s['name'] as String),
      ));
    }
    if (_busLocation != null && _busIcon != null) {
      markers.add(Marker(
        markerId: const MarkerId('bus'),
        position: _busLocation!,
        icon: _busIcon!,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 2,
      ));
    }
    // Custom pins
    if (_pinIcon != null) {
      for (final pin in _customPins) {
        final id = pin['id'] as String;
        markers.add(Marker(
          markerId: MarkerId('pin_$id'),
          position: LatLng(
            (pin['latitude']  as num).toDouble(),
            (pin['longitude'] as num).toDouble(),
          ),
          icon: _pinIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1,
          infoWindow: InfoWindow(
            title: pin['label'] as String,
            snippet:
                'Notify ${pin['notify_minutes_before']} min before · Tap to remove',
            onTap: () => _deletePin(id, pin['label'] as String),
          ),
        ));
      }
    }
    return markers;
  }

  Widget _mapBtn(String svgPath, VoidCallback onTap, ThemeData theme) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 40, height: 40,
          child: Center(
            child: SvgPicture.asset(svgPath, width: 20, height: 20,
                colorFilter: ColorFilter.mode(theme.colorScheme.onSurface, BlendMode.srcIn)),
          ),
        ),
      );

  Set<Polyline> _buildPolylines() {
    if (_routePoints.isEmpty) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: const Color(0xFF1A237E),
        width: 5,
      ),
    };
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Prefer live GPS-derived progress; fall back to the trip's current_stop_index
    // when there is no live location or the route is unavailable.
    final hasLiveGps = _hasActiveTrip && _busLocation != null && _liveStopIndex >= 0;
    final effectiveStopIndex = hasLiveGps ? _liveStopIndex : _busStopIndex;
    final myStopStatus = _myStopStatus();

    // Reflect pins added or removed elsewhere (e.g. the profile screen, which
    // invalidates this provider) without needing a full map reload.
    if (!_loading && _busId.isNotEmpty) {
      ref.listen(customPinsProvider(_busId), (_, next) {
        next.whenData((pins) {
          if (mounted) setState(() => _customPins = pins);
        });
      });
    }

    return Scaffold(
      body: _loading
          ? const Center(child: LottieLoading())
          : Stack(
              children: [
                // Web demo has no Maps JS workflow — show a placeholder; the
                // stop timeline and ETA below stay fully functional.
                if (kIsWeb)
                  const Positioned.fill(child: WebMapPlaceholder())
                else
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(23.15, 77.15),
                      zoom: 10,
                    ),
                    onMapCreated: _onMapCreated,
                    onLongPress: _addPin,
                    markers: _buildMarkers(),
                    polylines: _buildPolylines(),
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    padding: const EdgeInsets.only(bottom: 80),
                  ),
                // GPS button — centres on the bus, not the passenger
                if (!kIsWeb)
                  Positioned(
                    right: 12,
                    bottom: 175,
                    child: Material(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(28),
                      elevation: 3,
                      child: _mapBtn('assets/icons/gps.svg', _centerOnBus,
                          Theme.of(context)),
                    ),
                  ),
                DraggableScrollableSheet(
                  initialChildSize: 0.22,
                  minChildSize: 0.12,
                  maxChildSize: 0.85,
                  builder: (_, controller) => _BottomSheet(
                    scrollController: controller,
                    busNumber: _busNumber,
                    stops: _stops,
                    myStopId: _myStopId,
                    hasActiveTrip: _hasActiveTrip,
                    currentStopIndex: effectiveStopIndex,
                    busAtStop: _busAtStop,
                    busOffRoute: _busOffRoute,
                    hasLiveGps: hasLiveGps,
                    myStopStatus: myStopStatus,
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Bottom sheet ─────────────────────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final String busNumber;
  final List<Map<String, dynamic>> stops;
  final String myStopId;
  final bool hasActiveTrip;
  final int currentStopIndex;
  final bool busAtStop;
  final bool busOffRoute;
  final bool hasLiveGps;
  final String? myStopStatus;

  const _BottomSheet({
    required this.scrollController,
    required this.busNumber,
    required this.stops,
    required this.myStopId,
    required this.hasActiveTrip,
    required this.currentStopIndex,
    required this.busAtStop,
    required this.busOffRoute,
    required this.hasLiveGps,
    required this.myStopStatus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.zero,
        children: [
          // Drag handle
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Text('Bus $busNumber',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                _LiveBadge(live: hasActiveTrip),
                if (hasActiveTrip && busOffRoute) ...[
                  const SizedBox(width: 6),
                  const _OffRouteBadge(),
                ],
                const Spacer(),
                Text(
                  stops.isNotEmpty
                      ? '${stops.first['name']} → ${stops.last['name']}'
                      : '',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          // Live ETA / status for the passenger's own stop.
          if (myStopStatus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.directions_bus_rounded,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        myStopStatus!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          // Stop timeline
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 24),
            child: Column(
              children: List.generate(stops.length, (i) {
                final s        = stops[i];
                final isMyStop = s['id'] == myStopId;
                // "Bus here" when the bus is physically at the stop (or when we
                // only have the trip index to go on); "Arriving" when live GPS
                // shows it en route to this stop.
                final isBusHere  = hasActiveTrip &&
                    i == currentStopIndex && (busAtStop || !hasLiveGps);
                final isArriving = hasActiveTrip &&
                    hasLiveGps && !busAtStop && i == currentStopIndex;
                final isPassed   = hasActiveTrip && i < currentStopIndex;
                final isLast     = i == stops.length - 1;

                return _StopRow(
                  name: s['name'] as String,
                  isMyStop: isMyStop,
                  isBusHere: isBusHere,
                  isArriving: isArriving,
                  isPassed: isPassed,
                  isLast: isLast,
                  theme: theme,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  final bool live;
  const _LiveBadge({required this.live});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: live ? Colors.green.shade50 : theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: live ? Colors.green.shade400 : theme.colorScheme.outlineVariant),
      ),
      child: Text(
        live ? '● LIVE' : 'No Trip',
        style: theme.textTheme.labelSmall?.copyWith(
          color: live ? Colors.green.shade700 : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _OffRouteBadge extends StatelessWidget {
  const _OffRouteBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade400),
      ),
      child: Text(
        '⚠ Off route',
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.orange.shade900,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StopRow extends StatelessWidget {
  final String name;
  final bool isMyStop;
  final bool isBusHere;
  final bool isArriving;
  final bool isPassed;
  final bool isLast;
  final ThemeData theme;

  const _StopRow({
    required this.name,
    required this.isMyStop,
    required this.isBusHere,
    required this.isArriving,
    required this.isPassed,
    required this.isLast,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot + line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                _dot(),
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isPassed
                            ? const Color(0xFF1A237E)
                            : theme.colorScheme.outlineVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Label
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: (isMyStop || isBusHere || isArriving)
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isPassed && !isMyStop
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isBusHere) _tag('Bus here', const Color(0xFF3D3D8F), Colors.white),
                  if (isArriving) _tag('Arriving', const Color(0xFF1565C0), const Color(0xFFE3F2FD)),
                  if (isMyStop) _tag('Your stop', Colors.green.shade700, Colors.green.shade50),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot() {
    if (isBusHere || isArriving) {
      return Container(
        width: 24, height: 24,
        decoration: const BoxDecoration(
            color: Color(0xFF1565C0), shape: BoxShape.circle),
        child: Center(
          child: SvgPicture.asset('assets/icons/bus.svg', width: 14, height: 14,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
        ),
      );
    }
    if (isMyStop) {
      return Container(
        width: 20, height: 20,
        margin: const EdgeInsets.only(top: 2),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.green.shade600, width: 2.5),
        ),
      );
    }
    return Container(
      width: 14, height: 14,
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: isPassed ? const Color(0xFF1A237E) : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isPassed ? const Color(0xFF1A237E) : theme.colorScheme.outline,
          width: 2,
        ),
      ),
    );
  }

  Widget _tag(String label, Color textColor, Color bgColor) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: textColor.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: textColor, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Bus icon widget (offscreen render → BitmapDescriptor) ────────────────────

class _BusIconWidget extends StatelessWidget {
  final double size;
  const _BusIconWidget({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF3D3D8F),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(size * 0.22),
          child: SvgPicture.asset(
            'assets/icons/bus.svg',
            colorFilter:
                const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
