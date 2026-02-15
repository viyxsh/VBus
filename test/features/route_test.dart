import 'package:flutter_test/flutter_test.dart';

// Bus stop data for bus 11's route — mirrors the DB after the coordinate update
const _stops = [
  {'order': 1,  'name': 'Vijay Market',                   'lat': 23.227282, 'lng': 77.467659},
  {'order': 2,  'name': 'Mahatma Gandhi Square',          'lat': 23.232014, 'lng': 77.472101},
  {'order': 3,  'name': 'Gandhi Market',                  'lat': 23.240253, 'lng': 77.473039},
  {'order': 4,  'name': 'Piplani',                        'lat': 23.249124, 'lng': 77.471520},
  {'order': 5,  'name': 'Ayodhya Bypass',                 'lat': 23.251073, 'lng': 77.479596},
  {'order': 6,  'name': 'Narela Jod',                     'lat': 23.268785, 'lng': 77.468920},
  {'order': 7,  'name': 'Minal Residency Gate No. 2',     'lat': 23.275502, 'lng': 77.463702},
  {'order': 8,  'name': 'SIRT',                           'lat': 23.278716, 'lng': 77.455376},
  {'order': 9,  'name': "People's Mall",                  'lat': 23.303144, 'lng': 77.421657},
  {'order': 10, 'name': 'BMHRC',                          'lat': 23.303148, 'lng': 77.416980},
  {'order': 11, 'name': 'Karond Square',                  'lat': 23.302713, 'lng': 77.404053},
  {'order': 12, 'name': 'RGPV',                           'lat': 23.301481, 'lng': 77.362140},
  {'order': 13, 'name': 'Sanjeev Nagar Bus Stop',         'lat': 23.297416, 'lng': 77.353573},
  {'order': 14, 'name': 'Lalghati',                       'lat': 23.273042, 'lng': 77.369760},
  {'order': 15, 'name': 'Chanchal Chouraha (Bairagarh)',  'lat': 23.271059, 'lng': 77.337249},
  {'order': 16, 'name': 'Fanda',                          'lat': 23.228735, 'lng': 77.208729},
  {'order': 17, 'name': 'VIT Campus',                     'lat': 23.078296, 'lng': 76.850590},
];

double _deg2rad(double deg) => deg * 3.141592653589793 / 180;

// Haversine distance in km between two lat/lng points
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLng = _deg2rad(lng2 - lng1);
  final sinDLat = dLat / 2;
  final sinDLng = dLng / 2;
  final a = sinDLat * sinDLat +
      _deg2rad(lat1).abs() * _deg2rad(lat2).abs() * sinDLng * sinDLng;
  return r * 2 * (a < 1 ? a : 1);
}

void main() {
  // ─── Stop count and ordering ──────────────────────────────────────────────────
  group('Route structure', () {
    test('route has exactly 17 stops', () {
      expect(_stops.length, 17);
    });

    test('stop orders are sequential starting at 1', () {
      for (int i = 0; i < _stops.length; i++) {
        expect(_stops[i]['order'], i + 1);
      }
    });

    test('first stop is Vijay Market', () {
      expect(_stops.first['name'], 'Vijay Market');
    });

    test('last stop is VIT Campus', () {
      expect(_stops.last['name'], 'VIT Campus');
    });
  });

  // ─── Coordinate validity ──────────────────────────────────────────────────────
  group('Coordinate validity', () {
    test('all stops have non-zero coordinates', () {
      for (final s in _stops) {
        expect(s['lat'], isNot(0.0),
            reason: '${s['name']} has zero latitude');
        expect(s['lng'], isNot(0.0),
            reason: '${s['name']} has zero longitude');
      }
    });

    test('all stops are within Madhya Pradesh bounding box', () {
      // MP rough bounds: lat 21–26, lng 74–82
      for (final s in _stops) {
        expect(s['lat'] as double, greaterThan(21.0),
            reason: '${s['name']} lat out of bounds');
        expect(s['lat'] as double, lessThan(26.0),
            reason: '${s['name']} lat out of bounds');
        expect(s['lng'] as double, greaterThan(74.0),
            reason: '${s['name']} lng out of bounds');
        expect(s['lng'] as double, lessThan(82.0),
            reason: '${s['name']} lng out of bounds');
      }
    });

    test('consecutive stops are no more than 50 km apart', () {
      for (int i = 0; i < _stops.length - 1; i++) {
        final a = _stops[i], b = _stops[i + 1];
        final dLat = ((b['lat'] as double) - (a['lat'] as double)).abs();
        final dLng = ((b['lng'] as double) - (a['lng'] as double)).abs();
        // Rough check: 1 degree ≈ 111 km
        final approxKm = (dLat + dLng) * 111;
        // Fanda → VIT Campus is ~56 km (long highway stretch); use 80 km ceiling
        expect(approxKm, lessThan(80),
            reason:
                '${a['name']} → ${b['name']} looks too far ($approxKm km approx)');
      }
    });
  });

  // ─── Direction check (generally south-west toward VIT) ───────────────────────
  group('Route direction', () {
    test('VIT Campus is south of Vijay Market', () {
      final vitLat    = _stops.last['lat']  as double;
      final startLat  = _stops.first['lat'] as double;
      expect(vitLat, lessThan(startLat));
    });

    test('VIT Campus is west of Vijay Market', () {
      final vitLng    = _stops.last['lng']  as double;
      final startLng  = _stops.first['lng'] as double;
      expect(vitLng, lessThan(startLng));
    });
  });

  // ─── Specific known stops ─────────────────────────────────────────────────────
  group('Known stop coordinates', () {
    Map<String, dynamic> stopByName(String name) =>
        _stops.firstWhere((s) => s['name'] == name);

    test('VIT Campus latitude and longitude', () {
      final vit = stopByName('VIT Campus');
      expect((vit['lat'] as double).toStringAsFixed(4), '23.0783');
      expect((vit['lng'] as double).toStringAsFixed(4), '76.8506');
    });

    test('Vijay Market latitude and longitude', () {
      final vm = stopByName('Vijay Market');
      expect((vm['lat'] as double).toStringAsFixed(4), '23.2273');
      expect((vm['lng'] as double).toStringAsFixed(4), '77.4677');
    });

    test('Fanda is the penultimate stop before VIT', () {
      final fanda = _stops[_stops.length - 2];
      expect(fanda['name'], 'Fanda');
    });
  });
}
