import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../../core/services/route_service.dart';
import '../../../../../core/widgets/web_map_placeholder.dart';
import '../../../../../data/repositories/tracking_repository.dart';

class ConductorMapTab extends ConsumerStatefulWidget {
  const ConductorMapTab({super.key});

  @override
  ConsumerState<ConductorMapTab> createState() => _ConductorMapTabState();
}

class _ConductorMapTabState extends ConsumerState<ConductorMapTab> {
  GoogleMapController? _mapController;

  String _busId = '';
  String _busNumber = '';
  String? _tripId;
  int _busStopIndex = 0;
  List<Map<String, dynamic>> _stops = [];
  List<LatLng> _routePoints = [];
  bool _hasActiveTrip = false;
  LatLng? _myLocation;
  bool _gpsAvailable = false;

  bool _loading = true;
  StreamSubscription<Position>? _locationSub;
  StreamSubscription<List<Map<String, dynamic>>>? _tripSub;
  LatLng? _busMarkerPosition; // stop-based fallback when GPS unavailable

  BitmapDescriptor? _stopIcon;
  BitmapDescriptor? _busIcon;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
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

  // Fallback icon — drawn with canvas only (no widget context needed).
  Future<BitmapDescriptor> _busMarkerIconFallback(double size) async {
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

  // SVG icon — renders the custom bus.svg via an offscreen RepaintBoundary.
  // Must be called after at least one await so the widget is in the tree.
  Future<BitmapDescriptor> _busMarkerIconFromSvg(double size) async {
    final completer = Completer<BitmapDescriptor>();
    final key = GlobalKey();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -10000,
        top: -10000,
        child: RepaintBoundary(
          key: key,
          child: _BusIconWidget(size: size),
        ),
      ),
    );

    Overlay.of(context).insert(entry);

    // Two frames: first to layout, second to paint the SVG.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final boundary = key.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
          if (boundary != null) {
            final img = await boundary.toImage(pixelRatio: 3.0);
            final data =
                await img.toByteData(format: ui.ImageByteFormat.png);
            completer.complete(
              data != null
                  ? BitmapDescriptor.bytes(
                      data.buffer.asUint8List(),
                      imagePixelRatio: 3.0,
                    )
                  : await _busMarkerIconFallback(size),
            );
          } else {
            completer.complete(await _busMarkerIconFallback(size));
          }
        } catch (e) {
          debugPrint('[MAP] svg icon capture error: $e');
          completer.complete(await _busMarkerIconFallback(size));
        } finally {
          entry.remove();
        }
      });
    });

    return completer.future;
  }

  // ─── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _load() async {
    try {
      final tracking = ref.read(trackingRepositoryProvider);
      final cred = await tracking.conductorBusInfo();

      _busId = cred['bus_id'] as String;
      final bus = cred['buses'] as Map;
      _busNumber = bus['bus_number'] as String;
      final routeId = bus['route_id'] as String;

      _stops = (await tracking.stopsForRoute(routeId))
        ..sort((a, b) => (a['stop_order'] as num).compareTo(b['stop_order'] as num));
      debugPrint('[MAP] first stop: ${_stops.isNotEmpty ? _stops.first['name'] : 'none'}'
          ', last: ${_stops.isNotEmpty ? _stops.last['name'] : 'none'}');
      _routePoints = await RouteService.getRoutePoints(_stops);

      _stopIcon = await _circleMarkerIcon(fill: Colors.white, stroke: const Color(0xFF37474F), size: 32);
      // Start SVG icon creation concurrently after several awaits (first frame is built).
      final busIconFuture = _busMarkerIconFromSvg(32);

      final trip = await tracking.ongoingTripForBus(_busId);

      _hasActiveTrip = trip != null;
      if (_hasActiveTrip) {
        _tripId = trip!['id'] as String;
        _busStopIndex = (trip['current_stop_index'] as num).toInt();
        // Prime the stop-based marker so it shows before GPS lock
        if (_busStopIndex < _stops.length) {
          final s = _stops[_busStopIndex];
          final lat = (s['latitude']  as num).toDouble();
          final lng = (s['longitude'] as num).toDouble();
          if (lat != 0 || lng != 0) _busMarkerPosition = LatLng(lat, lng);
        }
        _startTripListener();
      }
      // Always track GPS so conductor sees their own location on the map.
      // Broadcast to Supabase only during active trips.
      await _startTracking();

      _busIcon = await busIconFuture;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('[CONDUCTOR_MAP] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTripListener() {
    _tripSub = ref
        .read(trackingRepositoryProvider)
        .watchTrip(_tripId!)
        .listen((data) {
      if (data.isEmpty || !mounted) return;
      final newIdx = (data.first['current_stop_index'] as num).toInt();
      if (newIdx != _busStopIndex) {
        setState(() => _busStopIndex = newIdx);
        _moveToStop(newIdx);
      }
    });
  }

  void _moveToStop(int idx) {
    if (idx >= _stops.length) return;
    final stop = _stops[idx];
    final lat = (stop['latitude']  as num).toDouble();
    final lng = (stop['longitude'] as num).toDouble();
    if (lat == 0 && lng == 0) return;
    final pos = LatLng(lat, lng);
    if (mounted) setState(() => _busMarkerPosition = pos);
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: pos, zoom: 15)),
    );
  }

  Future<void> _startTracking() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() { _gpsAvailable = false; _myLocation = null; });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      if (mounted) setState(() { _gpsAvailable = false; _myLocation = null; });
      return;
    }

    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (pos) async {
        final loc = LatLng(pos.latitude, pos.longitude);
        if (mounted) setState(() { _gpsAvailable = true; _myLocation = loc; });

      // Only broadcast to passengers during an active trip
      if (!_hasActiveTrip || _tripId == null) return;
      try {
        await ref.read(trackingRepositoryProvider).upsertBusLocation(
              busId: _busId,
              tripId: _tripId!,
              latitude: pos.latitude,
              longitude: pos.longitude,
              heading: pos.heading,
              speedKmh: pos.speed * 3.6,
            );
      } catch (e) {
        debugPrint('[CONDUCTOR_MAP] upsert error: $e');
      }
    },
    onError: (_) {
      if (mounted) setState(() { _gpsAvailable = false; _myLocation = null; });
    });
  }

  void _recenter() {
    if (_myLocation == null) return;
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _myLocation!, zoom: 15),
      ),
    );
  }

  // ─── Map helpers ──────────────────────────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitBounds();
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
      markers.add(Marker(
        markerId: MarkerId(s['id'] as String),
        position: LatLng(lat, lng),
        icon: _stopIcon!,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(title: s['name'] as String),
      ));
    }
    if (_busIcon != null) {
      if (_myLocation != null) {
        // Live GPS — full opacity
        markers.add(Marker(
          markerId: const MarkerId('bus'),
          position: _myLocation!,
          icon: _busIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
          alpha: 1.0,
        ));
      } else if (_busMarkerPosition != null) {
        // Stop-based estimate (manual advance, no GPS) — faded at same size
        markers.add(Marker(
          markerId: const MarkerId('bus'),
          position: _busMarkerPosition!,
          icon: _busIcon!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 2,
          alpha: 0.55,
        ));
      }
    }
    return markers;
  }

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
    return Scaffold(
      body: _loading
          ? const Center(child: LottieLoading())
          : Stack(
              children: [
                // Web demo has no Maps JS workflow — show a placeholder.
                if (kIsWeb)
                  const Positioned.fill(child: WebMapPlaceholder())
                else
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(23.15, 77.15),
                      zoom: 10,
                    ),
                    onMapCreated: _onMapCreated,
                    markers: _buildMarkers(),
                    polylines: _buildPolylines(),
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    padding: const EdgeInsets.only(bottom: 80),
                  ),
                // GPS recenter button above the route list
                if (!kIsWeb)
                  Positioned(
                    right: 12,
                    bottom: 175,
                    child: _MapControls(
                      gpsAvailable: _gpsAvailable,
                      onRecenter: _recenter,
                    ),
                  ),
                DraggableScrollableSheet(
                  initialChildSize: 0.22,
                  minChildSize: 0.12,
                  maxChildSize: 0.85,
                  builder: (_, controller) => _ConductorBottomSheet(
                    scrollController: controller,
                    busNumber: _busNumber,
                    stops: _stops,
                    hasActiveTrip: _hasActiveTrip,
                    busStopIndex: _busStopIndex,
                    broadcasting: _myLocation != null,
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Conductor bottom sheet ───────────────────────────────────────────────────

class _ConductorBottomSheet extends StatelessWidget {
  final ScrollController scrollController;
  final String busNumber;
  final List<Map<String, dynamic>> stops;
  final bool hasActiveTrip;
  final int busStopIndex;
  final bool broadcasting;

  const _ConductorBottomSheet({
    required this.scrollController,
    required this.busNumber,
    required this.stops,
    required this.hasActiveTrip,
    required this.busStopIndex,
    required this.broadcasting,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Text('Bus $busNumber',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                _badge(
                  hasActiveTrip
                      ? (broadcasting ? '● Broadcasting' : '● Getting GPS…')
                      : 'No Trip',
                  hasActiveTrip ? Colors.green.shade700 : theme.colorScheme.onSurfaceVariant,
                  hasActiveTrip ? Colors.green.shade50 : theme.colorScheme.surfaceContainerHigh,
                  hasActiveTrip ? Colors.green.shade400 : theme.colorScheme.outlineVariant,
                  theme,
                ),
                const Spacer(),
                Text(
                  stops.isNotEmpty
                      ? '${stops.first['name']} → ${stops.last['name']}'
                      : '',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 16, 24),
            child: Column(
              children: List.generate(stops.length, (i) {
                final s         = stops[i];
                final isCurrent = hasActiveTrip && i == busStopIndex;
                final isPassed  = hasActiveTrip && i < busStopIndex;
                final isLast    = i == stops.length - 1;

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 24,
                        child: Column(
                          children: [
                            _dot(isCurrent, isPassed, theme),
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
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  s['name'] as String,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: isCurrent
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    color: isPassed
                                        ? theme.colorScheme.onSurfaceVariant
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF3D3D8F),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Current',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(bool isCurrent, bool isPassed, ThemeData theme) {
    if (isCurrent) {
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

  Widget _badge(String label, Color textColor, Color bgColor,
      Color borderColor, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(label,
          style: theme.textTheme.labelSmall?.copyWith(
              color: textColor, fontWeight: FontWeight.w600)),
    );
  }
}

// ─── Custom map controls ──────────────────────────────────────────────────────

class _MapControls extends StatelessWidget {
  final bool gpsAvailable;
  final VoidCallback onRecenter;

  const _MapControls({
    required this.gpsAvailable,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      elevation: 3,
      child: _btn(
        svgPath: 'assets/icons/gps.svg',
        color: gpsAvailable
            ? theme.colorScheme.primary
            : theme.colorScheme.onSurfaceVariant,
        onTap: gpsAvailable ? onRecenter : null,
      ),
    );
  }

  Widget _btn({
    required String svgPath,
    required Color color,
    required VoidCallback? onTap,
    BoxBorder? border,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(border: border),
        child: Center(
          child: SvgPicture.asset(svgPath, width: 20, height: 20,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
        ),
      ),
    );
  }
}

// ─── Offscreen bus icon widget ────────────────────────────────────────────────
// Rendered into a RepaintBoundary to produce the BitmapDescriptor for the map.

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
