import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/supabase_constants.dart';
import '../../main.dart';

part 'tracking_repository.g.dart';

@riverpod
TrackingRepository trackingRepository(Ref ref) => TrackingRepository();

/// Data access for live bus tracking: bus/route info, stops, trips and live
/// GPS locations. Shared by the passenger and conductor map tabs and the
/// attendance screen.
class TrackingRepository {
  /// The signed-in conductor's staff record + bus/route info.
  Future<Map<String, dynamic>> conductorBusInfo() async {
    final userId = supabase.auth.currentUser!.id;
    final cred = await supabase
        .from(SupabaseConstants.staffCredentials)
        .select('id, bus_id, buses(bus_number, route_id)')
        .eq('auth_user_id', userId)
        .single();
    return Map<String, dynamic>.from(cred);
  }

  /// The signed-in passenger's bus assignment + bus/route info.
  Future<Map<String, dynamic>> passengerBusInfo() async {
    final userId = supabase.auth.currentUser!.id;
    final profile = await supabase
        .from(SupabaseConstants.passengers)
        .select('bus_id, stop_id, buses(bus_number, route_id)')
        .eq('id', userId)
        .single();
    return Map<String, dynamic>.from(profile);
  }

  /// All stops on a route with coordinates, ordered by stop order.
  Future<List<Map<String, dynamic>>> stopsForRoute(String routeId) async {
    final data = await supabase
        .from(SupabaseConstants.busStops)
        .select('id, name, latitude, longitude, stop_order')
        .eq('route_id', routeId)
        .order('stop_order');
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Today's ongoing trip for a bus, or null when none is running.
  Future<Map<String, dynamic>?> ongoingTripForBus(String busId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final trip = await supabase
        .from(SupabaseConstants.trips)
        .select('id, current_stop_index')
        .eq('bus_id', busId)
        .eq('trip_date', today)
        .eq('state', 'ongoing')
        .maybeSingle();
    return trip == null ? null : Map<String, dynamic>.from(trip);
  }

  /// The latest known bus location for a specific trip.
  Future<Map<String, dynamic>?> busLocationForTrip(
      String busId, String tripId) async {
    final loc = await supabase
        .from(SupabaseConstants.busLocations)
        .select('latitude, longitude, speed_kmh, trip_id')
        .eq('bus_id', busId)
        .eq('trip_id', tripId)
        .maybeSingle();
    return loc == null ? null : Map<String, dynamic>.from(loc);
  }

  /// Realtime stream of a trip row (used to track current_stop_index).
  Stream<List<Map<String, dynamic>>> watchTrip(String tripId) => supabase
      .from(SupabaseConstants.trips)
      .stream(primaryKey: ['id']).eq('id', tripId);

  /// Subscribes to all bus_locations changes for a bus, invoking [onRow] with
  /// each new record. Returns the channel so the caller can unsubscribe.
  RealtimeChannel subscribeBusLocations({
    required String busId,
    required void Function(Map<String, dynamic> row) onRow,
  }) {
    return supabase
        .channel('bus_loc_$busId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConstants.busLocations,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'bus_id',
            value: busId,
          ),
          callback: (payload) => onRow(payload.newRecord),
        )
        .subscribe();
  }

  /// Broadcasts the conductor's current GPS position for an active trip.
  Future<void> upsertBusLocation({
    required String busId,
    required String tripId,
    required double latitude,
    required double longitude,
    required double heading,
    required double speedKmh,
  }) async {
    if (AppConfig.demoMode) return; // the seeded cron job drives the location
    await supabase.from(SupabaseConstants.busLocations).upsert({
      'bus_id': busId,
      'trip_id': tripId,
      'latitude': latitude,
      'longitude': longitude,
      'heading': heading,
      'speed_kmh': speedKmh,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }
}
