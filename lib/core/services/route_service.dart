import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Fetches a road-following polyline from OSRM (free, no API key).
/// Result is cached in memory for the lifetime of the app session.
class RouteService {
  RouteService._();

  static final Map<String, List<LatLng>> _cache = {};

  /// Cache key built from first + last stop coordinates — auto-invalidates
  /// if stop order or coordinates change between sessions.
  static String _cacheKey(List<Map<String, dynamic>> stops) {
    if (stops.isEmpty) return '';
    final f = stops.first;
    final l = stops.last;
    return '${f['latitude']},${f['longitude']}'
        '→${l['latitude']},${l['longitude']}';
  }

  /// Call this to force a fresh fetch (e.g. after updating stop coordinates).
  static void clearCache() => _cache.clear();

  static Future<List<LatLng>> getRoutePoints(
      List<Map<String, dynamic>> stops) async {
    final key = _cacheKey(stops);
    if (_cache.containsKey(key)) return _cache[key]!;

    final valid = stops.where((s) {
      final lat = (s['latitude']  as num).toDouble();
      final lng = (s['longitude'] as num).toDouble();
      return lat != 0.0 && lng != 0.0;
    }).toList();

    if (valid.isEmpty) return [];

    try {
      // OSRM uses lng,lat order
      final coords = valid
          .map((s) =>
              '${(s['longitude'] as num).toDouble()},'
              '${(s['latitude']  as num).toDouble()}')
          .join(';');

      // radiuses tells OSRM to snap each waypoint to the nearest road
      // within 100m, avoiding detours caused by coordinates being on the
      // wrong side of the road.
      final radiuses = List.filled(valid.length, '100').join(';');
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coords'
        '?overview=full&geometries=polyline&radiuses=$radiuses',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final encoded =
            (data['routes'] as List).first['geometry'] as String;
        _cache[key] = _decode(encoded);
        debugPrint('[ROUTE] road polyline fetched — ${_cache[key]!.length} points');
        return _cache[key]!;
      }
    } catch (e) {
      debugPrint('[ROUTE] OSRM error: $e — falling back to straight lines');
    }

    // Fallback: straight lines between stops
    _cache[key] = valid
        .map((s) => LatLng(
              (s['latitude']  as num).toDouble(),
              (s['longitude'] as num).toDouble(),
            ))
        .toList();
    return _cache[key]!;
  }

  /// Standard Google encoded-polyline decoder (also used by OSRM).
  static List<LatLng> _decode(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
