import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/enums/approval_status.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/services/message_notification_service.dart';
import '../../../core/utils/email_utils.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../main.dart';

part 'auth_provider.g.dart';

@Riverpod(keepAlive: true)
Stream<AuthUser?> authState(Ref ref) {
  return supabase.auth.onAuthStateChange.asyncMap((event) async {
    debugPrint('[AUTH] event=${event.event}, session=${event.session != null}');
    final session = event.session;
    if (session == null) {
      // User signed out — stop listening for messages
      MessageNotificationService.stop();
      return null;
    }

    final user = session.user;
    final email = user.email ?? '';
    debugPrint('[AUTH] email=$email');
    debugPrint('[AUTH] uid=${user.id}');

    // Conductor
    debugPrint('[AUTH] step: conductor check');
    if (email.endsWith('@vbus.internal')) {
      debugPrint('[AUTH] role=conductor');
      MessageNotificationService.start();
      return AuthUser(id: user.id, email: email, role: UserRole.conductor);
    }

    // Invalid university email — sign out silently
    debugPrint('[AUTH] step: university email check');
    final isValid = EmailUtils.isValidUniversityEmail(email);
    debugPrint('[AUTH] isValidUniversityEmail=$isValid');
    if (!isValid) {
      debugPrint('[AUTH] invalid email domain, signing out');
      supabase.auth.signOut();
      return null;
    }

    // Passenger — check profile existence and approval status
    debugPrint('[AUTH] step: fetching passenger profile');
    try {
      final status =
          await ref.read(userRepositoryProvider).passengerApprovalStatus(user.id);

      debugPrint('[AUTH] approval_status=$status');

      final authUser = AuthUser(
        id: user.id,
        email: email,
        role: UserRole.passenger,
        approvalStatus:
            status != null ? ApprovalStatusX.fromString(status) : null,
      );
      debugPrint('[AUTH] returning user, approvalStatus=${authUser.approvalStatus}');
      // Start listening for chat messages once the user is fully resolved
      if (authUser.approvalStatus?.name == 'approved') {
        MessageNotificationService.start();
      }
      return authUser;
    } catch (e, st) {
      debugPrint('[AUTH] profile fetch error: $e\n$st');
      rethrow;
    }
  });
}

class AuthUser {
  final String id;
  final String email;
  final UserRole role;
  final ApprovalStatus? approvalStatus; // null means no profile yet

  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    this.approvalStatus,
  });
}
