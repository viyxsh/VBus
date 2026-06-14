import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/supabase_constants.dart';
import '../../main.dart';

part 'seat_repository.g.dart';

@riverpod
SeatRepository seatRepository(Ref ref) => SeatRepository();

/// Data access for the daily seat-booking screen.
class SeatRepository {
  /// The passenger's bus, user type and seat layout.
  Future<Map<String, dynamic>> seatBusInfo() async {
    final userId = supabase.auth.currentUser!.id;
    final profile = await supabase
        .from(SupabaseConstants.passengers)
        .select(
          'bus_id, user_type, '
          'buses(bus_number, left_seats, student_seats, '
          'faculty_reserved_rows_left, faculty_reserved_rows_right)',
        )
        .eq('id', userId)
        .single();
    return Map<String, dynamic>.from(profile);
  }

  /// All seat bookings on a bus for a given date, with booker names.
  Future<List<Map<String, dynamic>>> bookingsForDate(
      String busId, String dateStr) async {
    final data = await supabase
        .from(SupabaseConstants.seatBookings)
        .select('seat_number, passenger_id, passengers(name)')
        .eq('bus_id', busId)
        .eq('booking_date', dateStr);
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Clears the current passenger's booking for a date.
  Future<void> clearMyBooking(String dateStr) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase
        .from(SupabaseConstants.seatBookings)
        .delete()
        .eq('passenger_id', userId)
        .eq('booking_date', dateStr);
  }

  /// Books a seat for the current passenger. Throws a PostgrestException with
  /// code 23505 if the seat was taken concurrently.
  Future<void> bookSeat({
    required String busId,
    required int seatNumber,
    required String dateStr,
  }) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase.from(SupabaseConstants.seatBookings).insert({
      'bus_id': busId,
      'passenger_id': userId,
      'seat_number': seatNumber,
      'booking_date': dateStr,
    });
  }

  String get currentUserId => supabase.auth.currentUser!.id;
}
