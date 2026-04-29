import 'package:supabase_flutter/supabase_flutter.dart';

String authUserRole(User user) {
  return ((user.appMetadata['role'] ?? user.userMetadata?['role']) as String?)
          ?.toLowerCase() ??
      'user';
}

bool isAdminAuthUser(User user) => authUserRole(user) == 'admin';
