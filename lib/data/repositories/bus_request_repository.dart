import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_config.dart';
import '../../core/constants/supabase_constants.dart';
import '../../main.dart';

part 'bus_request_repository.g.dart';

@riverpod
BusRequestRepository busRequestRepository(Ref ref) => BusRequestRepository();

class BusRequestRepository {
  Future<List<Map<String, dynamic>>> pendingRequestsForBus(
      String busId) async {
    final data = await supabase
        .from(SupabaseConstants.busRequests)
        .select('''
          id, passenger_id, bus_id, status, request_type, requested_at,
          passengers(name, institute_id, email, phone, user_type)
        ''')
        .eq('bus_id', busId)
        .eq('status', 'pending')
        .eq('request_type', 'join')
        .order('requested_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(data as List);
    final seen = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final row in rows) {
      final pid = row['passenger_id'] as String;
      if (seen.add(pid)) {
        deduped.add(row);
      }
    }
    return deduped;
  }

  Future<Map<String, dynamic>?> myPendingRequest(String passengerId) async {
    final data = await supabase
        .from(SupabaseConstants.busRequests)
        .select('''
          id, bus_id, status, request_type, rejection_reason, requested_at,
          buses(bus_number)
        ''')
        .eq('passenger_id', passengerId)
        .eq('status', 'pending')
        .order('requested_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  Future<Map<String, dynamic>?> latestRequest(String passengerId) async {
    final data = await supabase
        .from(SupabaseConstants.busRequests)
        .select('''
          id, bus_id, status, request_type, rejection_reason, requested_at,
          buses(bus_number)
        ''')
        .eq('passenger_id', passengerId)
        .order('requested_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return data != null ? Map<String, dynamic>.from(data) : null;
  }

  Future<void> createJoinRequest({
    required String passengerId,
    required String busId,
  }) async {
    if (AppConfig.demoMode) return;
    await supabase.from(SupabaseConstants.busRequests).insert({
      'passenger_id': passengerId,
      'bus_id': busId,
      'status': 'pending',
      'request_type': 'join',
    });
  }

  /// Cancels any existing pending join requests for this passenger.
  Future<void> cancelPendingRequests(String passengerId) async {
    if (AppConfig.demoMode) return;
    await supabase
        .from(SupabaseConstants.busRequests)
        .update({'status': 'rejected', 'rejection_reason': 'Cancelled by user'})
        .eq('passenger_id', passengerId)
        .eq('status', 'pending');
  }

  Future<void> createLeaveRequest({
    required String passengerId,
    required String busId,
  }) async {
    if (AppConfig.demoMode) return;
    await supabase.from(SupabaseConstants.busRequests).insert({
      'passenger_id': passengerId,
      'bus_id': busId,
      'status': 'approved',
      'request_type': 'leave',
    });
  }

  Future<void> approveRequest(String requestId, String conductorId) async {
    if (AppConfig.demoMode) return;

    await supabase.rpc('approve_bus_request', params: {
      'p_request_id': requestId,
      'p_responded_by': conductorId,
    });
  }

  Future<void> rejectRequest({
    required String requestId,
    required String conductorId,
    String? reason,
  }) async {
    if (AppConfig.demoMode) return;

    await supabase.rpc('reject_bus_request', params: {
      'p_request_id': requestId,
      'p_responded_by': conductorId,
      'p_reason': reason,
    });
  }

  RealtimeChannel subscribeToBusRequests(
    String busId,
    void Function(Map<String, dynamic> payload) onUpdate,
  ) {
    return supabase
        .channel('bus_requests_$busId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: SupabaseConstants.busRequests,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'bus_id',
            value: busId,
          ),
          callback: (payload) => onUpdate(payload.newRecord),
        )
        .subscribe();
  }
}
