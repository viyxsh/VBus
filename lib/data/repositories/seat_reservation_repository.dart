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
  // ─── Demo state ────────────────────────────────────────────────────────────
  // The web demo can't read the real seat_reservations table (RLS is on with
  // no read policies, so a public visitor would only ever see an empty list),
  // and demo mode must never write to it. Demo mode therefore simulates the
  // whole reservation workflow in memory. Seat numbers assume the demo bus's
  // standard 18-left layout: 19, 20 and 21 are the first right-side row
  // (R1-R3), which sits inside the faculty zone the demo guarantees.
  // List queries skip the bus filter because the demo runs on a single bus.

  static final List<SeatReservation> _demoReservations = [
    SeatReservation(
      id: 'demo-res-1',
      busId: '',
      passengerId: 'demo-faculty-rao',
      seatNumber: 19,
      status: 'approved',
      requestedAt: DateTime.now().subtract(const Duration(days: 2)),
      passengerName: 'Dr. Rao',
      passengerInstituteId: 'FAC1001',
      passengerUserType: 'faculty',
    ),
    SeatReservation(
      id: 'demo-res-2',
      busId: '',
      passengerId: 'demo-faculty-sen',
      seatNumber: 20,
      status: 'approved',
      requestedAt: DateTime.now().subtract(const Duration(days: 1)),
      passengerName: 'Prof. Sen',
      passengerInstituteId: 'FAC1002',
      passengerUserType: 'faculty',
    ),
    // A pending request so the demo conductor's approve/reject sheet has
    // something to act on.
    SeatReservation(
      id: 'demo-res-3',
      busId: '',
      passengerId: 'demo-faculty-kulkarni',
      seatNumber: 21,
      status: 'pending',
      requestedAt: DateTime.now().subtract(const Duration(hours: 5)),
      passengerName: 'Dr. Kulkarni',
      passengerInstituteId: 'FAC1003',
      passengerUserType: 'faculty',
    ),
  ];

  /// Replaces a demo reservation with a copy carrying a new status. The model
  /// fields are final, so status changes rebuild the row.
  static SeatReservation _withStatus(
    SeatReservation r,
    String status, {
    String? reason,
  }) {
    return SeatReservation(
      id: r.id,
      busId: r.busId,
      passengerId: r.passengerId,
      seatNumber: r.seatNumber,
      status: status,
      requestedAt: r.requestedAt,
      respondedAt: DateTime.now(),
      rejectionReason: reason,
      passengerName: r.passengerName,
      passengerInstituteId: r.passengerInstituteId,
      passengerUserType: r.passengerUserType,
    );
  }

  /// Create a new reservation request (status = 'pending').
  Future<void> createReservation({
    required String busId,
    required String passengerId,
    required int seatNumber,
  }) async {
    if (AppConfig.demoMode) {
      // One reservation per passenger per bus, matching the table's unique
      // constraint on (bus_id, passenger_id).
      _demoReservations.removeWhere(
        (r) => r.passengerId == passengerId && r.isPending,
      );
      _demoReservations.add(
        SeatReservation(
          id: 'demo-res-${DateTime.now().microsecondsSinceEpoch}',
          busId: busId,
          passengerId: passengerId,
          seatNumber: seatNumber,
          status: 'pending',
          requestedAt: DateTime.now(),
          passengerName: 'Faculty (demo)',
        ),
      );
      return;
    }
    await supabase.from(SupabaseConstants.seatReservations).insert({
      'bus_id': busId,
      'passenger_id': passengerId,
      'seat_number': seatNumber,
      'status': 'pending',
    });
  }

  /// Cancel the current user's own reservation (sets status to 'rejected').
  Future<void> cancelReservation(String reservationId) async {
    if (AppConfig.demoMode) {
      final idx = _demoReservations.indexWhere((r) => r.id == reservationId);
      if (idx != -1) {
        _demoReservations[idx] = _withStatus(
          _demoReservations[idx],
          'rejected',
          reason: 'Cancelled by user',
        );
      }
      return;
    }
    await supabase
        .from(SupabaseConstants.seatReservations)
        .update({'status': 'rejected', 'rejection_reason': 'Cancelled by user'})
        .eq('id', reservationId);
  }

  /// Returns the current user's active approved reservation, or null.
  Future<SeatReservation?> myActiveReservation() async {
    if (AppConfig.demoMode) {
      final me = supabase.auth.currentUser?.id;
      for (final r in _demoReservations) {
        if (r.isApproved && r.passengerId == me) return r;
      }
      return null;
    }
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
    if (AppConfig.demoMode) {
      final me = supabase.auth.currentUser?.id;
      for (final r in _demoReservations) {
        if (r.isPending && r.passengerId == me) return r;
      }
      return null;
    }
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
    if (AppConfig.demoMode) {
      final result = <int, String>{};
      for (final r in _demoReservations) {
        if (r.isApproved) {
          result[r.seatNumber] = r.passengerName ?? 'Reserved';
        }
      }
      return result;
    }
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
    if (AppConfig.demoMode) {
      final pending = _demoReservations.where((r) => r.isPending).toList()
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return pending;
    }
    final data = await supabase
        .from(SupabaseConstants.seatReservations)
        .select(
          'id, bus_id, passenger_id, seat_number, status, requested_at, '
          'passengers(name, institute_id, user_type)',
        )
        .eq('bus_id', busId)
        .eq('status', 'pending')
        .order('requested_at', ascending: false);
    return (data as List)
        .map((r) => SeatReservation.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// All approved reservations for a bus (used for the conductor's manage view).
  Future<List<SeatReservation>> approvedReservationsForBus(String busId) async {
    if (AppConfig.demoMode) {
      return _demoReservations.where((r) => r.isApproved).toList()
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    }
    final data = await supabase
        .from(SupabaseConstants.seatReservations)
        .select(
          'id, bus_id, passenger_id, seat_number, status, requested_at, '
          'passengers(name, institute_id, user_type)',
        )
        .eq('bus_id', busId)
        .eq('status', 'approved')
        .order('requested_at', ascending: false);
    return (data as List)
        .map((r) => SeatReservation.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// The responding conductor is derived server-side from the auth session.
  Future<void> approveReservation(String reservationId) async {
    if (AppConfig.demoMode) {
      final idx = _demoReservations.indexWhere((r) => r.id == reservationId);
      if (idx != -1) {
        _demoReservations[idx] = _withStatus(
          _demoReservations[idx],
          'approved',
        );
      }
      return;
    }
    await supabase.rpc(
      'approve_seat_reservation',
      params: {'p_reservation_id': reservationId},
    );
  }

  Future<void> rejectReservation({
    required String reservationId,
    String? reason,
  }) async {
    if (AppConfig.demoMode) {
      final idx = _demoReservations.indexWhere((r) => r.id == reservationId);
      if (idx != -1) {
        _demoReservations[idx] = _withStatus(
          _demoReservations[idx],
          'rejected',
          reason: reason,
        );
      }
      return;
    }
    await supabase.rpc(
      'reject_seat_reservation',
      params: {'p_reservation_id': reservationId, 'p_reason': reason},
    );
  }

  /// Remove an active reservation (conductor force-removal or unreserve).
  Future<void> removeReservation(String reservationId) async {
    if (AppConfig.demoMode) {
      _demoReservations.removeWhere((r) => r.id == reservationId);
      return;
    }
    await supabase.rpc(
      'remove_seat_reservation',
      params: {'p_reservation_id': reservationId},
    );
  }
}
