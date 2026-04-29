import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSessionService {
  const AuthSessionService._();

  static Future<void> signOutCurrentUser() {
    return Supabase.instance.client.auth.signOut();
  }
}
