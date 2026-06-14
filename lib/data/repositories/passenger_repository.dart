import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/supabase_constants.dart';
import '../../main.dart';

part 'passenger_repository.g.dart';

@riverpod
PassengerRepository passengerRepository(Ref ref) => PassengerRepository();

/// Data access for the signed-in passenger: their profile, boarding stop,
/// custom map pins and seat-booking history.
class PassengerRepository {
  /// The signed-in user's Google avatar URL, if any.
  String? get currentAvatarUrl =>
      supabase.auth.currentUser?.userMetadata?['avatar_url'] as String?;

  /// The passenger's profile joined with their bus number.
  Future<Map<String, dynamic>> profile() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from(SupabaseConstants.passengers)
        .select(
            'name, email, phone, user_type, institute_id, bus_id, stop_id, buses(bus_number)')
        .eq('id', userId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateProfile({
    required String name,
    required String phone,
    String? stopId,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from(SupabaseConstants.passengers).update({
      'name': name,
      'phone': phone,
      if (stopId != null) 'stop_id': stopId,
    }).eq('id', userId);
  }

  /// The stops on a bus's route, ordered by stop order.
  Future<List<Map<String, dynamic>>> stopsForBus(String busId) async {
    final bus = await supabase
        .from(SupabaseConstants.buses)
        .select('route_id')
        .eq('id', busId)
        .single();
    final data = await supabase
        .from(SupabaseConstants.busStops)
        .select('id, name')
        .eq('route_id', bus['route_id'] as String)
        .order('stop_order');
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// The passenger's custom map pins for a bus, newest first.
  Future<List<Map<String, dynamic>>> customPins(String busId) async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('custom_pins')
        .select()
        .eq('passenger_id', userId)
        .eq('bus_id', busId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<void> deleteCustomPin(String id) async {
    await supabase.from('custom_pins').delete().eq('id', id);
  }

  /// Creates a custom map pin for the current passenger and returns the row.
  Future<Map<String, dynamic>> addCustomPin({
    required String busId,
    required String label,
    required double latitude,
    required double longitude,
    required int notifyMinutesBefore,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('custom_pins')
        .insert({
          'passenger_id': userId,
          'bus_id': busId,
          'label': label,
          'latitude': latitude,
          'longitude': longitude,
          'notify_minutes_before': notifyMinutesBefore,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(data);
  }

  Future<void> markPinNotified(String id) async {
    await supabase
        .from('custom_pins')
        .update({'notified_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }

  /// The passenger's seat bookings over the last 7 days, with the seat layout
  /// needed to compute seat labels.
  Future<List<Map<String, dynamic>>> recentSeatBookings() async {
    final userId = supabase.auth.currentUser!.id;
    final busId = (await supabase
        .from(SupabaseConstants.passengers)
        .select('bus_id')
        .eq('id', userId)
        .single())['bus_id'] as String;

    final today = DateTime.now();
    final fromDate = DateTime(today.year, today.month, today.day - 6);
    final fromStr = fromDate.toIso8601String().substring(0, 10);

    final data = await supabase
        .from(SupabaseConstants.seatBookings)
        .select('seat_number, booking_date, buses(left_seats, student_seats)')
        .eq('passenger_id', userId)
        .eq('bus_id', busId)
        .gte('booking_date', fromStr)
        .order('booking_date', ascending: false);
    return List<Map<String, dynamic>>.from(data as List);
  }
}
