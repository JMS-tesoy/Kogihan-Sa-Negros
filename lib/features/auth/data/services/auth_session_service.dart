import 'dart:async';
import '../../../../app/bootstrap/land_finder_app_bootstrap.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/auth_config.dart';

class AuthSessionService {
  const AuthSessionService._();

  static Future<void> signOutCurrentUser() async {
    await onUserLoggedOut();
    await Supabase.instance.client.auth.signOut();
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
    return signInWithPassword(
      email: AuthConfig.devUserEmail,
      password: AuthConfig.devUserPassword,
    );
  }

  static Future<User?> signInWithDevAgentShortcut() async {
    return signInWithPassword(
      email: AuthConfig.devAgentEmail,
      password: AuthConfig.devAgentPassword,
    );
  }

  static Future<void> signInWithGoogle() {
    return Supabase.instance.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : AuthConfig.redirectUrl,
    );
  }

  static StreamSubscription<AuthState> listenForLoginRouting({
    required Future<void> Function(User? user) onSignedIn,
  }) {
    return Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        unawaited(onSignedIn(data.session?.user));
      }
    });
  }

  static StreamSubscription<AuthState> listenForPasswordRecovery({
    required Future<void> Function() onPasswordRecovery,
  }) {
    return Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        unawaited(onPasswordRecovery());
      }
    });
  }
}
