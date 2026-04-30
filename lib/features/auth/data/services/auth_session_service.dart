import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/auth_config.dart';

class AuthSessionService {
  const AuthSessionService._();

  static Future<void> signOutCurrentUser() {
    return Supabase.instance.client.auth.signOut();
  }

  static Future<User?> signInWithPassword({
    required String email,
    required String password,
  }) async {
    final AuthResponse response = await Supabase.instance.client.auth
        .signInWithPassword(email: email, password: password);
    return response.user;
  }

  static Future<User?> signInWithDevUserShortcut() async {
    try {
      return await signInWithPassword(
        email: AuthConfig.devUserEmail,
        password: AuthConfig.devUserPassword,
      );
    } on AuthException catch (error) {
      final String message = error.message.toLowerCase();
      final bool shouldCreateAccount =
          message.contains('invalid login credentials') ||
          message.contains('user not found');

      if (!shouldCreateAccount) rethrow;
    }

    await Supabase.instance.client.auth.signUp(
      email: AuthConfig.devUserEmail,
      password: AuthConfig.devUserPassword,
      data: const {'role': 'user'},
    );

    return signInWithPassword(
      email: AuthConfig.devUserEmail,
      password: AuthConfig.devUserPassword,
    );
  }

  static Future<void> signInWithGoogle() {
    return Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : AuthConfig.redirectUrl,
    );
  }

  static StreamSubscription<AuthState> listenForLoginRouting({
    required Future<void> Function() onPasswordRecovery,
    required Future<void> Function(User? user) onSignedIn,
  }) {
    return Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        unawaited(onPasswordRecovery());
        return;
      }

      if (data.event == AuthChangeEvent.signedIn) {
        unawaited(onSignedIn(data.session?.user));
      }
    });
  }
}
