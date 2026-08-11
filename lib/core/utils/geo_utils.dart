import 'dart:math';

/// Great-circle distance in kilometres between two WGS84 points
/// (haversine formula, spherical earth R = 6371 km).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLng = (lng2 - lng1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLng / 2) *
          sin(dLng / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

/// Perpendicular distance (km) from point P to the great-earth segment AB,
/// measured to the closest interpolated point on the straight segment.
double pointToSegmentKm(
    double px, double py, double ax, double ay, double bx, double by) {
  final abx = bx - ax;
  final aby = by - ay;
  final dot = abx * abx + aby * aby;
  if (dot == 0) return haversineKm(px, py, ax, ay); // A == B
  var t = ((px - ax) * abx + (py - ay) * aby) / dot;
  t = t.clamp(0.0, 1.0);
  final cx = ax + t * abx;
  final cy = ay + t * aby;
  return haversineKm(px, py, cx, cy);
}
