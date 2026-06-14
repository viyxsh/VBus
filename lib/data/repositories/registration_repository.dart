import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/supabase_constants.dart';
import '../../main.dart';

part 'registration_repository.g.dart';

@riverpod
RegistrationRepository registrationRepository(Ref ref) =>
    RegistrationRepository();

/// Data access for passenger onboarding: the registration form's dropdown
/// data, receipt uploads, and the pending-approval screen.
class RegistrationRepository {
  /// The signed-in user's email (used to derive student/faculty type).
  String get currentUserEmail => supabase.auth.currentUser!.email!;

  Future<List<Map<String, dynamic>>> cities() async {
    final data =
        await supabase.from(SupabaseConstants.cities).select().order('name');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> busesForCity(String cityId) async {
    final data = await supabase
        .from(SupabaseConstants.buses)
        .select('id, bus_number, route_id')
        .eq('city_id', cityId)
        .eq('is_active', true)
        .order('bus_number');
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<List<Map<String, dynamic>>> stopsForRoute(String routeId) async {
    final data = await supabase
        .from(SupabaseConstants.busStops)
        .select('id, name, stop_order')
        .eq('route_id', routeId)
        .order('stop_order');
    return List<Map<String, dynamic>>.from(data as List);
  }

  /// Uploads the current user's fee receipt and returns its storage path.
  Future<String> uploadReceipt(Uint8List bytes) async {
    final userId = supabase.auth.currentUser!.id;
    final storagePath = '$userId/receipt.jpg';
    await supabase.storage.from(SupabaseConstants.receiptsBucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return storagePath;
  }

  /// Creates or updates the passenger profile, then refreshes the session so
  /// the auth state re-resolves the new approval status.
  Future<void> registerPassenger({
    required String name,
    required String instituteId,
    required String email,
    required String phone,
    required String userType,
    required String cityId,
    required String busId,
    required String stopId,
    required String? receiptPath,
    required bool approved,
  }) async {
    await supabase.from(SupabaseConstants.passengers).upsert({
      'id': supabase.auth.currentUser!.id,
      'name': name,
      'institute_id': instituteId,
      'email': email,
      'phone': phone,
      'user_type': userType,
      'city_id': cityId,
      'bus_id': busId,
      'stop_id': stopId,
      'receipt_url': receiptPath,
      'approval_status': approved ? 'approved' : 'pending',
    });
    await supabase.auth.refreshSession();
  }

  // ─── Pending approval ────────────────────────────────────────────────────

  Future<Map<String, dynamic>> approvalInfo() async {
    final userId = supabase.auth.currentUser!.id;
    final data = await supabase
        .from(SupabaseConstants.passengers)
        .select('approval_status, rejection_reason')
        .eq('id', userId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  /// Subscribes to approval-status changes for the current user.
  RealtimeChannel subscribeApproval(
      void Function(Map<String, dynamic> row) onUpdate) {
    final userId = supabase.auth.currentUser!.id;
    return supabase
        .channel('passenger_approval_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.passengers,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }

  /// Re-uploads a receipt and resets the profile to pending.
  Future<void> resubmitReceipt(Uint8List bytes) async {
    final userId = supabase.auth.currentUser!.id;
    final storagePath = await uploadReceipt(bytes);
    await supabase.from(SupabaseConstants.passengers).update({
      'receipt_url': storagePath,
      'approval_status': 'pending',
      'rejection_reason': null,
    }).eq('id', userId);
  }
}
