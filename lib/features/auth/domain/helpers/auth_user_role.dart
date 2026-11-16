import 'package:supabase_flutter/supabase_flutter.dart';

String authUserRole(User user) {
  final Object? role = user.appMetadata['role'];
  if (role is! String || role.trim().isEmpty) {
    return 'user';
  }
  return role.trim().toLowerCase();
}

bool isAdminAuthUser(User user) => authUserRole(user) == 'admin';

bool isAgentAuthUser(User user) => authUserRole(user) == 'agent';
