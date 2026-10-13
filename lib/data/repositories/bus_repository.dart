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
  // Demo-only faculty-row overrides set from the conductor's bus-controls
  // sheet, keyed by bus id. The passenger seat screen reads this in the same
  // session so a demo conductor's change is visible without touching the DB.
  static final Map<String, Map<String, int>> demoFacultyRows = {};

  /// Pins the demo bus layout and faculty rows. Only used in demo mode.
  ///
  /// The seed row for the demo student's bus says student_seats = 44, which
  /// lays out 38 right seats before the back bench; the real buses seat
  /// 18 left + 30 right + 6 back, so demo mode pins that layout. A bus with
  /// no faculty rows configured (the demo bus has 0) gets four rows per side
  /// (L1-L8 and R1-R12) so the faculty zone is visible; a bus with real
  /// configured rows keeps them. An override saved from the bus-controls
  /// sheet in this session always wins.
  static void applyDemoBusConfig(String busId, Map bus) {
    bus['left_seats'] = 18;
    bus['student_seats'] = 36;
    final dbLeft = ((bus['faculty_reserved_rows_left'] as num?) ?? 0).toInt();
    final dbRight = ((bus['faculty_reserved_rows_right'] as num?) ?? 0).toInt();
    bus['faculty_reserved_rows_left'] = dbLeft > 0 ? dbLeft : 4;
    bus['faculty_reserved_rows_right'] = dbRight > 0 ? dbRight : 4;
    final override = demoFacultyRows[busId];
    if (override != null) {
      bus['faculty_reserved_rows_left'] = override['left'];
      bus['faculty_reserved_rows_right'] = override['right'];
    }
  }

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
    await supabase.rpc(
      'remove_passenger',
      params: {'p_passenger_id': passengerId},
    );
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
    if (AppConfig.demoMode) {
      BusRepository.applyDemoBusConfig(data['bus_id'] as String, bus);
    }
    debugPrint(
      '[BUS_REPO] conductorProfile loaded: '
      'bus_id=${data['bus_id']} '
      'facultyRowsLeft=${bus['faculty_reserved_rows_left']} '
      'facultyRowsRight=${bus['faculty_reserved_rows_right']}',
    );
    return Map<String, dynamic>.from(data);
  }

  Future<void> updateConductorProfile({
    required String displayName,
    required String phone,
  }) async {
    if (AppConfig.demoMode) return;
    final userId = supabase.auth.currentUser!.id;
    await supabase
        .from(SupabaseConstants.staffCredentials)
        .update({'display_name': displayName, 'phone': phone})
        .eq('auth_user_id', userId);
  }

  Future<void> updateFacultyRows({
    required String busId,
    required int reservedRowsLeft,
    required int reservedRowsRight,
  }) async {
    if (AppConfig.demoMode) {
      demoFacultyRows[busId] = {
        'left': reservedRowsLeft,
        'right': reservedRowsRight,
      };
      return;
    }
    debugPrint(
      '[BUS_REPO] updateFacultyRows called: '
      'busId=$busId reservedRowsLeft=$reservedRowsLeft reservedRowsRight=$reservedRowsRight '
      'demoMode=${AppConfig.demoMode}',
    );

    // Use RPC (SECURITY DEFINER) to bypass RLS on the buses table.
    // Requires: CREATE FUNCTION update_faculty_rows in Supabase SQL Editor.
    try {
      final result = await supabase.rpc(
        'update_faculty_rows',
        params: {
          'p_bus_id': busId,
          'p_rows_left': reservedRowsLeft,
          'p_rows_right': reservedRowsRight,
        },
      );
      debugPrint('[BUS_REPO] RPC result=$result');

      // Verify read-back
      final verify = await supabase
          .from(SupabaseConstants.buses)
          .select('id, faculty_reserved_rows_left, faculty_reserved_rows_right')
          .eq('id', busId)
          .single();
      debugPrint(
        '[BUS_REPO] VERIFY after update: id=${verify['id']} '
        'facultyRowsLeft=${verify['faculty_reserved_rows_left']} '
        'facultyRowsRight=${verify['faculty_reserved_rows_right']}',
      );
    } catch (e) {
      debugPrint('[BUS_REPO] updateFacultyRows EXCEPTION: $e');
      rethrow;
    }
  }
}
