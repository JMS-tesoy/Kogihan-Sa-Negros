import 'package:supabase_flutter/supabase_flutter.dart';

String authUserRole(User user) {
  final Object? role = user.appMetadata['role'];
  return (role is String ? role : 'user').toLowerCase();
}

bool isAdminAuthUser(User user) => authUserRole(user) == 'admin';
