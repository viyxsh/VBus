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

  /// Removes a passenger from a bus by marking them rejected.
  Future<void> rejectPassenger(String passengerId) async {
    if (AppConfig.demoMode) return;
    await supabase
        .from(SupabaseConstants.passengers)
        .update({'approval_status': 'rejected'})
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
    if (AppConfig.demoMode) return;
    await supabase.from(SupabaseConstants.buses).update({
      'faculty_reserved_rows_left': reservedRowsLeft,
      'faculty_reserved_rows_right': reservedRowsRight,
    }).eq('id', busId);
  }
}
