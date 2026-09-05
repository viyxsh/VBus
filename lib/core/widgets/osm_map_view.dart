import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

/// Shared OpenStreetMap (flutter_map / Leaflet-style) view for the web build.
///
/// Mobile keeps `google_maps_flutter`; web uses this so no Maps JavaScript
/// API key is required. Markers are plain Flutter widgets (no
/// BitmapDescriptor needed) styled to match the mobile Google-Map markers.
class OsmMapView extends StatelessWidget {
  final fm.MapController mapController;
  final List<ll.LatLng> routePoints;
  final List<fm.Marker> markers;
  final ll.LatLng initialCenter;
  final double initialZoom;
  final void Function(ll.LatLng)? onTap;
  final void Function(ll.LatLng)? onLongPress;
  final VoidCallback? onMapReady;

  const OsmMapView({
    super.key,
    required this.mapController,
    this.routePoints = const [],
    this.markers = const [],
    this.initialCenter = const ll.LatLng(23.15, 77.15),
    this.initialZoom = 11,
    this.onTap,
    this.onLongPress,
    this.onMapReady,
  });

  @override
  Widget build(BuildContext context) {
    return fm.FlutterMap(
      mapController: mapController,
      options: fm.MapOptions(
        initialCenter: initialCenter,
        initialZoom: initialZoom,
        maxZoom: 19,
        onMapReady: onMapReady,
        onTap: onTap == null ? null : (_, p) => onTap!(p),
        onLongPress: onLongPress == null ? null : (_, p) => onLongPress!(p),
        interactionOptions:
            const fm.InteractionOptions(flags: fm.InteractiveFlag.all),
      ),
      children: [
        fm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.vbus.vbusf',
          maxZoom: 19,
        ),
        if (routePoints.length > 1)
          fm.PolylineLayer(
            polylines: [
              fm.Polyline(
                points: routePoints,
                color: const Color(0xFF1A237E),
                strokeWidth: 5,
              ),
            ],
          ),
        if (markers.isNotEmpty) fm.MarkerLayer(markers: markers),
        fm.RichAttributionWidget(
          alignment: fm.AttributionAlignment.bottomLeft,
          showFlutterMapAttribution: false,
          attributions: [
            fm.TextSourceAttribution(
              '© OpenStreetMap contributors',
              onTap: () => launchUrl(
                Uri.parse('https://www.openstreetmap.org/copyright'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Conversion + camera + marker helpers shared by the web map screens.
abstract final class OsmMapHelpers {
  static ll.LatLng toOsm(gmaps.LatLng p) => ll.LatLng(p.latitude, p.longitude);

  static List<ll.LatLng> toOsmList(List<gmaps.LatLng> points) =>
      points.map(toOsm).toList();

  /// Fits [controller] to [stops] (+ optional bus position). No-op when empty.
  static void fitBounds(
    fm.MapController controller,
    List<Map<String, dynamic>> stops, {
    gmaps.LatLng? bus,
  }) {
    final valid = stops.where((s) {
      final lat = (s['latitude'] as num).toDouble();
      final lng = (s['longitude'] as num).toDouble();
      return lat != 0 && lng != 0;
    }).toList();
    if (valid.isEmpty && bus == null) return;

    double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
    void include(double lat, double lng) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    for (final s in valid) {
      include(
        (s['latitude'] as num).toDouble(),
        (s['longitude'] as num).toDouble(),
      );
    }
    if (bus != null) include(bus.latitude, bus.longitude);

    // Single point → just centre on it instead of fitting zero-area bounds.
    if (minLat == maxLat && minLng == maxLng) {
      controller.move(ll.LatLng(minLat, minLng), 15);
      return;
    }
    controller.fitCamera(
      fm.CameraFit.bounds(
        bounds: fm.LatLngBounds(
          ll.LatLng(minLat, minLng),
          ll.LatLng(maxLat, maxLng),
        ),
        padding: const EdgeInsets.fromLTRB(40, 40, 40, 160),
      ),
    );
  }

  static void centerOn(fm.MapController controller, gmaps.LatLng target,
      {double zoom = 15}) {
    controller.move(toOsm(target), zoom);
  }

  // ─── Markers (styled to match the mobile BitmapDescriptor icons) ───

  static fm.Marker stopMarker({
    required String id,
    required double lat,
    required double lng,
    required String name,
    bool isMyStop = false,
  }) {
    return fm.Marker(
      point: ll.LatLng(lat, lng),
      width: 32,
      height: 32,
      alignment: Alignment.center,
      child: GestureDetector(
        child: Tooltip(
          message: name,
          child: Container(
            width: isMyStop ? 28 : 26,
            height: isMyStop ? 28 : 26,
            decoration: BoxDecoration(
              color: isMyStop ? Colors.green.shade600 : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: isMyStop ? Colors.white : const Color(0xFF37474F),
                width: isMyStop ? 3 : 2.5,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static fm.Marker busMarker({
    required double lat,
    required double lng,
    double size = 34,
    double opacity = 1.0,
  }) {
    return fm.Marker(
      point: ll.LatLng(lat, lng),
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF3D3D8F),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
            ],
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
        ),
      ),
    );
  }

  static fm.Marker pinMarker({
    required String id,
    required double lat,
    required double lng,
    required String label,
    required VoidCallback onTap,
  }) {
    return fm.Marker(
      point: ll.LatLng(lat, lng),
      width: 34,
      height: 34,
      alignment: Alignment.center,
      child: GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: label,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFE65100),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26,
                    blurRadius: 3,
                    offset: Offset(0, 1)),
              ],
            ),
            child: const Icon(Icons.location_on_rounded,
                size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }

  static fm.Marker pickedMarker(double lat, double lng) {
    return fm.Marker(
      point: ll.LatLng(lat, lng),
      width: 44,
      height: 44,
      alignment: Alignment.topCenter,
      child: const Icon(Icons.location_pin, size: 44, color: Color(0xFFE65100)),
    );
  }
}
