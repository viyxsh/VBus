import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/services/route_service.dart';
import '../../../../core/widgets/lottie_widgets.dart';
import '../../../../data/repositories/passenger_repository.dart';

/// Full-screen map where the passenger taps to choose where a custom pin should
/// sit. Shows the bus route and its stops for context. Pops with the chosen
/// [LatLng], or null if cancelled.
class PinLocationPicker extends ConsumerStatefulWidget {
  final String busId;
  const PinLocationPicker({super.key, required this.busId});

  @override
  ConsumerState<PinLocationPicker> createState() => _PinLocationPickerState();
}

class _PinLocationPickerState extends ConsumerState<PinLocationPicker> {
  GoogleMapController? _mapController;
  List<Map<String, dynamic>> _stops = [];
  List<LatLng> _routePoints = [];
  LatLng? _picked;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _stops = await ref
          .read(passengerRepositoryProvider)
          .routeStopsForBus(widget.busId);
      _routePoints = await RouteService.getRoutePoints(_stops);
    } catch (e) {
      debugPrint('[PIN_PICKER] load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

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
      LatLngBounds(
          southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      80,
    ));
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    for (final s in _stops) {
      final lat = (s['latitude']  as num).toDouble();
      final lng = (s['longitude'] as num).toDouble();
      if (lat == 0 && lng == 0) continue;
      markers.add(Marker(
        markerId: MarkerId(s['id'] as String),
        position: LatLng(lat, lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: s['name'] as String),
      ));
    }
    if (_picked != null) {
      markers.add(Marker(
        markerId: const MarkerId('picked'),
        position: _picked!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Pin Location'),
        scrolledUnderElevation: 0,
      ),
      body: _loading
          ? const Center(child: LottieLoading())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(23.15, 77.15),
                    zoom: 10,
                  ),
                  onMapCreated: _onMapCreated,
                  onTap: (pos) => setState(() => _picked = pos),
                  markers: _buildMarkers(),
                  polylines: _buildPolylines(),
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                Positioned(
                  top: 12, left: 12, right: 12,
                  child: Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(10),
                    color: theme.colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Icon(Icons.touch_app_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _picked == null
                                  ? 'Tap anywhere on the map to drop a pin'
                                  : 'Tap again to move the pin',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: _picked == null
                      ? null
                      : () => Navigator.pop(context, _picked),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Use This Location',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ),
    );
  }
}
