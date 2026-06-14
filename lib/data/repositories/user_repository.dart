import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/supabase_constants.dart';
import '../../main.dart';

part 'user_repository.g.dart';

@riverpod
UserRepository userRepository(Ref ref) => UserRepository();

/// Shared lookups about the signed-in user that several features need:
/// their bus, their display name, and whether they are a conductor.
///
/// Centralising these removes the copy-pasted `bus_id` / name resolution
/// that previously lived in the chat screen, the map tabs and the message
/// notification service.
class UserRepository {
  String? get currentUserId => supabase.auth.currentUser?.id;

  String get currentEmail => supabase.auth.currentUser?.email ?? '';

  bool get isConductor =>
      currentEmail.endsWith(SupabaseConstants.conductorEmailDomain);

  /// Resolves the bus the current user belongs to, whether conductor or
  /// passenger. Returns null when the user has no bus assigned.
  Future<String?> currentUserBusId() async {
    final userId = currentUserId;
    if (userId == null) return null;

    if (isConductor) {
      final cred = await supabase
          .from(SupabaseConstants.staffCredentials)
          .select('bus_id')
          .eq('auth_user_id', userId)
          .maybeSingle();
      return cred?['bus_id'] as String?;
    }

    final passenger = await supabase
        .from(SupabaseConstants.passengers)
        .select('bus_id')
        .eq('id', userId)
        .maybeSingle();
    return passenger?['bus_id'] as String?;
  }

  /// The approval status string for a passenger, or null if they have no
  /// profile row yet.
  Future<String?> passengerApprovalStatus(String userId) async {
    final profile = await supabase
        .from(SupabaseConstants.passengers)
        .select('approval_status')
        .eq('id', userId)
        .maybeSingle();
    return profile?['approval_status'] as String?;
  }

  /// Display name for the current user — passenger name, else staff display
  /// name / username, else 'Unknown'.
  Future<String> currentUserDisplayName() async {
    final userId = currentUserId;
    if (userId == null) return 'Unknown';

    final passenger = await supabase
        .from(SupabaseConstants.passengers)
        .select('name')
        .eq('id', userId)
        .maybeSingle();
    if (passenger != null) return passenger['name'] as String;

    final cred = await supabase
        .from(SupabaseConstants.staffCredentials)
        .select('display_name, username')
        .eq('auth_user_id', userId)
        .maybeSingle();
    return (cred?['display_name'] as String?) ??
        (cred?['username'] as String?) ??
        'Unknown';
  }
}
