import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:vbusf/core/services/route_service.dart';
import 'package:vbusf/core/utils/geo_utils.dart';

// Bus 11's stop list — a contract mirroring the seeded rows in the live
// Supabase `bus_stops` table. If the DB is reseeded with different stops or
// coordinates, update this fixture to match.
const _stops = [
  {'order': 1, 'name': 'Vijay Market', 'lat': 23.227282, 'lng': 77.467659},
  {
    'order': 2,
    'name': 'Mahatma Gandhi Square',
    'lat': 23.232014,
    'lng': 77.472101,
  },
  {'order': 3, 'name': 'Gandhi Market', 'lat': 23.240253, 'lng': 77.473039},
  {'order': 4, 'name': 'Piplani', 'lat': 23.249124, 'lng': 77.471520},
  {'order': 5, 'name': 'Ayodhya Bypass', 'lat': 23.251073, 'lng': 77.479596},
  {'order': 6, 'name': 'Narela Jod', 'lat': 23.268785, 'lng': 77.468920},
  {
    'order': 7,
    'name': 'Minal Residency Gate No. 2',
    'lat': 23.275502,
    'lng': 77.463702,
  },
  {'order': 8, 'name': 'SIRT', 'lat': 23.278716, 'lng': 77.455376},
  {'order': 9, 'name': "People's Mall", 'lat': 23.303144, 'lng': 77.421657},
  {'order': 10, 'name': 'BMHRC', 'lat': 23.303148, 'lng': 77.416980},
  {'order': 11, 'name': 'Karond Square', 'lat': 23.302713, 'lng': 77.404053},
  {'order': 12, 'name': 'RGPV', 'lat': 23.301481, 'lng': 77.362140},
  {
    'order': 13,
    'name': 'Sanjeev Nagar Bus Stop',
    'lat': 23.297416,
    'lng': 77.353573,
  },
  {'order': 14, 'name': 'Lalghati', 'lat': 23.273042, 'lng': 77.369760},
  {
    'order': 15,
    'name': 'Chanchal Chouraha (Bairagarh)',
    'lat': 23.271059,
    'lng': 77.337249,
  },
  {'order': 16, 'name': 'Fanda', 'lat': 23.228735, 'lng': 77.208729},
  {'order': 17, 'name': 'VIT Campus', 'lat': 23.078296, 'lng': 76.850590},
];

void main() {
  // ─── Real code: haversineKm ───────────────────────────────────────────────────
  group('haversineKm', () {
    test('zero distance for identical points', () {
      expect(haversineKm(23.2, 77.4, 23.2, 77.4), 0);
    });

    test('one degree of latitude ≈ 111.2 km', () {
      final d = haversineKm(23.0, 77.0, 24.0, 77.0);
      expect(d, closeTo(111.19, 0.5));
    });

    test('one degree of longitude shrinks with latitude (cos φ)', () {
      final atEquator = haversineKm(0.0, 77.0, 0.0, 78.0);
      final atBhopal = haversineKm(23.0, 77.0, 23.0, 78.0);
      expect(atEquator, closeTo(111.19, 0.5));
      // cos(23°) ≈ 0.921
      expect(atBhopal, closeTo(111.19 * 0.921, 1.0));
      expect(atBhopal, lessThan(atEquator));
    });

    test('symmetric', () {
      final ab = haversineKm(23.227282, 77.467659, 23.078296, 76.850590);
      final ba = haversineKm(23.078296, 76.850590, 23.227282, 77.467659);
      expect(ab, closeTo(ba, 1e-9));
    });
  });

  // ─── Real code: pointToSegmentKm ─────────────────────────────────────────────
  group('pointToSegmentKm', () {
    // A 1°-of-latitude segment along the same meridian (~111 km long)
    const ax = 23.0, ay = 77.0, bx = 24.0, by = 77.0;

    test('zero when the point lies on the segment', () {
      expect(pointToSegmentKm(23.5, 77.0, ax, ay, bx, by), closeTo(0, 1e-9));
    });

    test('perpendicular offset for a point beside the segment midpoint', () {
      final d = pointToSegmentKm(23.5, 77.01, ax, ay, bx, by);
      // 0.01° of longitude at 23.5°N ≈ 1.02 km
      expect(d, closeTo(1.02, 0.1));
    });

    test('clamps to the nearest endpoint beyond the segment ends', () {
      final d = pointToSegmentKm(25.0, 77.0, ax, ay, bx, by);
      expect(d, closeTo(haversineKm(25.0, 77.0, bx, by), 1e-9));
    });

    test('degenerate segment (A == B) falls back to point distance', () {
      expect(
        pointToSegmentKm(23.5, 77.0, 23.0, 77.0, 23.0, 77.0),
        closeTo(haversineKm(23.5, 77.0, 23.0, 77.0), 1e-9),
      );
    });
  });

  // ─── Real code: OSRM / Google polyline decoder ────────────────────────────────
  group('RouteService.decodePolyline', () {
    test('decodes the standard Google polyline test vector', () {
      // Canonical example from the encoded-polyline algorithm format docs:
      // (38.5, -120.2), (40.7, -120.95), (43.252, -126.453)
      final points = RouteService.decodePolyline(
        r'_p~iF~ps|U_ulLnnqC_mqNvxq`@',
      );
      expect(points.length, 3);
      expect(points[0].latitude, closeTo(38.5, 1e-5));
      expect(points[0].longitude, closeTo(-120.2, 1e-5));
      expect(points[1].latitude, closeTo(40.7, 1e-5));
      expect(points[1].longitude, closeTo(-120.95, 1e-5));
      expect(points[2].latitude, closeTo(43.252, 1e-5));
      expect(points[2].longitude, closeTo(-126.453, 1e-5));
    });

    test('empty input yields no points', () {
      expect(RouteService.decodePolyline(''), isEmpty);
    });

    test('round-trips coordinates at 1e-5 precision', () {
      // A minimal hand-encoded single point: value 1 → 'A' (65)
      final points = RouteService.decodePolyline('AA');
      expect(points, [const LatLng(1e-5, 1e-5)]);
    });
  });

  // ─── Seed-data contract (mirrors live Supabase bus_stops rows) ────────────────
  group('Bus 11 seed data contract', () {
    test('route has exactly 17 sequential stops', () {
      expect(_stops.length, 17);
      for (int i = 0; i < _stops.length; i++) {
        expect(_stops[i]['order'], i + 1);
      }
    });

    test('first and last stops', () {
      expect(_stops.first['name'], 'Vijay Market');
      expect(_stops.last['name'], 'VIT Campus');
    });

    test('all stops have non-zero coordinates inside Madhya Pradesh', () {
      for (final s in _stops) {
        expect(
          s['lat'] as double,
          allOf(greaterThan(21.0), lessThan(26.0)),
          reason: '${s['name']} latitude out of bounds',
        );
        expect(
          s['lng'] as double,
          allOf(greaterThan(74.0), lessThan(82.0)),
          reason: '${s['name']} longitude out of bounds',
        );
      }
    });

    test('consecutive stops are no more than 80 km apart', () {
      for (int i = 0; i < _stops.length - 1; i++) {
        final a = _stops[i], b = _stops[i + 1];
        final km = haversineKm(
          a['lat'] as double,
          a['lng'] as double,
          b['lat'] as double,
          b['lng'] as double,
        );
        expect(
          km,
          lessThan(80),
          reason:
              '${a['name']} → ${b['name']} looks too far (${km.toStringAsFixed(1)} km)',
        );
      }
    });

    test('route runs south-west toward VIT Campus', () {
      expect(
        _stops.last['lat'] as double,
        lessThan(_stops.first['lat'] as double),
      );
      expect(
        _stops.last['lng'] as double,
        lessThan(_stops.first['lng'] as double),
      );
    });
  });
}
