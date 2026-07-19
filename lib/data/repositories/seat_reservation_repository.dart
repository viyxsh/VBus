import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/supabase_constants.dart';
import '../../main.dart';
import '../models/seat_reservation.dart';

part 'seat_reservation_repository.g.dart';

@riverpod
SeatReservationRepository seatReservationRepository(Ref ref) =>
    SeatReservationRepository();

/// Data access for permanent seat reservations (faculty fixed-seat workflow).
class SeatReservationRepository {
  /// Create a new reservation request (status = 'pending').
  Future<void> createReservation({
    required String busId,
    required String passengerId,
    required int seatNumber,
  }) async {
    if (AppConfig.demoMode) return;
    await supabase.from(SupabaseConstants.seatReservations).insert({
      'bus_id': busId,
      'passenger_id': passengerId,
      'seat_number': seatNumber,
      'status': 'pending',
    });
  }

  /// Cancel the current user's own reservation (sets status to 'rejected').
  Future<void> cancelReservation(String reservationId) async {
    if (AppConfig.demoMode) return;
    await supabase
        .from(SupabaseConstants.seatReservations)
        .update({'status': 'rejected', 'rejection_reason': 'Cancelled by user'})
        .eq('id', reservationId);
  }

  /// Returns the current user's active approved reservation, or null.
  Future<SeatReservation?> myActiveReservation() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from(SupabaseConstants.seatReservations)
        .select()
        .eq('passenger_id', userId)
        .eq('status', 'approved')
        .maybeSingle();
    if (data == null) return null;
    return SeatReservation.fromMap(Map<String, dynamic>.from(data));
  }

  /// Returns the current user's pending reservation (at most one), or null.
  Future<SeatReservation?> myPendingReservation() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from(SupabaseConstants.seatReservations)
        .select()
        .eq('passenger_id', userId)
        .eq('status', 'pending')
        .maybeSingle();
    if (data == null) return null;
    return SeatReservation.fromMap(Map<String, dynamic>.from(data));
  }

  /// All approved (active) reservation seat numbers for a bus, keyed by
  /// seat_number → passenger name.
  Future<Map<int, String>> activeReservationsForBus(String busId) async {
    final data = await supabase
        .from(SupabaseConstants.seatReservations)
        .select('seat_number, passengers(name)')
        .eq('bus_id', busId)
        .eq('status', 'approved');
    final result = <int, String>{};
    for (final row in data as List) {
      final seatNum = (row['seat_number'] as num).toInt();
      final p = row['passengers'] as Map?;
      final name = p?['name'] as String? ?? 'Reserved';
      result[seatNum] = name;
    }
    return result;
  }

  // ─── Conductor-side ───────────────────────────────────────────────────────

  /// Pending seat reservations for a bus, with passenger details.
  Future<List<SeatReservation>> pendingReservationsForBus(String busId) async {
    final data = await supabase
        .from(SupabaseConstants.seatReservations)
        .select(
            'id, bus_id, passenger_id, seat_number, status, requested_at, '
            'passengers(name, institute_id, user_type)')
        .eq('bus_id', busId)
        .eq('status', 'pending')
        .order('requested_at', ascending: false);
    return (data as List)
        .map((r) => SeatReservation.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// All approved reservations for a bus (used for the conductor's manage view).
  Future<List<SeatReservation>> approvedReservationsForBus(String busId) async {
    final data = await supabase
        .from(SupabaseConstants.seatReservations)
        .select(
            'id, bus_id, passenger_id, seat_number, status, requested_at, '
            'passengers(name, institute_id, user_type)')
        .eq('bus_id', busId)
        .eq('status', 'approved')
        .order('requested_at', ascending: false);
    return (data as List)
        .map((r) => SeatReservation.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> approveReservation(
      String reservationId, String conductorId) async {
    if (AppConfig.demoMode) return;
    await supabase.rpc('approve_seat_reservation', params: {
      'p_reservation_id': reservationId,
      'p_responded_by': conductorId,
    });
  }

  Future<void> rejectReservation({
    required String reservationId,
    required String conductorId,
    String? reason,
  }) async {
    if (AppConfig.demoMode) return;
    await supabase.rpc('reject_seat_reservation', params: {
      'p_reservation_id': reservationId,
      'p_responded_by': conductorId,
      'p_reason': reason,
    });
  }

  /// Remove an active reservation (conductor force-removal or unreserve).
  Future<void> removeReservation(String reservationId) async {
    if (AppConfig.demoMode) return;
    await supabase.rpc('remove_seat_reservation', params: {
      'p_reservation_id': reservationId,
    });
  }
}
