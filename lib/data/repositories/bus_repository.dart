import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/supabase_constants.dart';
import '../../main.dart';

part 'bus_repository.g.dart';

@riverpod
BusRepository busRepository(Ref ref) => BusRepository();

/// Data access for buses, their passengers, and conductor-managed bus
/// configuration (reserved faculty rows, etc.).
class BusRepository {
  /// Approved passengers on a bus, ordered by name. Used by the conductor's
  /// new-message picker.
  Future<List<Map<String, dynamic>>> approvedPassengers(String busId) async {
    final data = await supabase
        .from(SupabaseConstants.passengers)
        .select('id, name, phone, user_type, institute_id')
        .eq('bus_id', busId)
        .eq('approval_status', 'approved')
        .order('name');
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// All passengers on a bus (any approval status), ordered by name. Used by
  /// the manage-passengers sheet.
  Future<List<Map<String, dynamic>>> busPassengers(String busId) async {
    final data = await supabase
        .from(SupabaseConstants.passengers)
        .select('id, name, institute_id, user_type, approval_status')
        .eq('bus_id', busId)
        .order('name');
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Removes a passenger from a bus by clearing bus_id and marking rejected.
  Future<void> rejectPassenger(String passengerId) async {
    if (AppConfig.demoMode) return;
    await supabase.from(SupabaseConstants.seatBookings).delete().eq(
      'passenger_id', passengerId,
    ).gte('booking_date', DateTime.now().toIso8601String().substring(0, 10));
    await supabase
        .from(SupabaseConstants.passengers)
        .update({
          'approval_status': 'rejected',
          'bus_id': null,
        })
        .eq('id', passengerId);
  }

  // ─── Conductor profile / bus config ──────────────────────────────────────

  /// The signed-in conductor's staff record joined with their bus config.
  Future<Map<String, dynamic>> conductorProfile() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from(SupabaseConstants.staffCredentials)
        .select(
          'id, display_name, username, phone, bus_id, '
          'buses(bus_number, left_seats, student_seats, '
          'faculty_reserved_rows_left, faculty_reserved_rows_right)',
        )
        .eq('auth_user_id', userId)
        .single();
    final bus = data['buses'] as Map;
    debugPrint('[BUS_REPO] conductorProfile loaded: '
        'bus_id=${data['bus_id']} '
        'facultyRowsLeft=${bus['faculty_reserved_rows_left']} '
        'facultyRowsRight=${bus['faculty_reserved_rows_right']}');
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateConductorProfile({
    required String displayName,
    required String phone,
  }) async {
    if (AppConfig.demoMode) return;
    final userId = supabase.auth.currentUser!.id;
    await supabase.from(SupabaseConstants.staffCredentials).update({
      'display_name': displayName,
      'phone': phone,
    }).eq('auth_user_id', userId);
  }

  Future<void> updateFacultyRows({
    required String busId,
    required int reservedRowsLeft,
    required int reservedRowsRight,
  }) async {
    debugPrint('[BUS_REPO] updateFacultyRows called: '
        'busId=$busId reservedRowsLeft=$reservedRowsLeft reservedRowsRight=$reservedRowsRight '
        'demoMode=${AppConfig.demoMode}');

    // Use RPC (SECURITY DEFINER) to bypass RLS on the buses table.
    // Requires: CREATE FUNCTION update_faculty_rows in Supabase SQL Editor.
    try {
      final result = await supabase.rpc('update_faculty_rows', params: {
        'p_bus_id': busId,
        'p_rows_left': reservedRowsLeft,
        'p_rows_right': reservedRowsRight,
      });
      debugPrint('[BUS_REPO] RPC result=$result');

      // Verify read-back
      final verify = await supabase
          .from(SupabaseConstants.buses)
          .select('id, faculty_reserved_rows_left, faculty_reserved_rows_right')
          .eq('id', busId)
          .single();
      debugPrint('[BUS_REPO] VERIFY after update: id=${verify['id']} '
          'facultyRowsLeft=${verify['faculty_reserved_rows_left']} '
          'facultyRowsRight=${verify['faculty_reserved_rows_right']}');
    } catch (e) {
      debugPrint('[BUS_REPO] updateFacultyRows EXCEPTION: $e');
      rethrow;
    }
  }
}
