import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_config.dart';
import '../../core/utils/email_utils.dart';
import '../../main.dart';

part 'auth_repository.g.dart';

@riverpod
AuthRepository authRepository(Ref ref) => AuthRepository();

class AuthRepository {
  Future<void> signInConductor(String username, String password) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      throw const AuthException('Username and password are required');
    }
    final email = EmailUtils.conductorEmail(username.trim());
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    await supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'com.vitbhopal.vbusf://login-callback',
    );
  }

  /// One-tap sign-in to the shared demo student account (web demo's dummy login).
  Future<void> signInDemoStudent() async {
    if (!AppConfig.hasDemoStudent) {
      throw const AuthException('Demo account is not configured.');
    }
    await supabase.auth.signInWithPassword(
      email: AppConfig.demoStudentEmail,
      password: AppConfig.demoStudentPassword,
    );
  }

  /// One-tap sign-in to the shared demo conductor account.
  Future<void> signInDemoConductor() async {
    if (!AppConfig.hasDemoConductor) {
      throw const AuthException('Demo account is not configured.');
    }
    final email = EmailUtils.conductorEmail(AppConfig.demoConductorUsername);
    await supabase.auth.signInWithPassword(
      email: email,
      password: AppConfig.demoConductorPassword,
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
