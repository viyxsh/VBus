import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}
