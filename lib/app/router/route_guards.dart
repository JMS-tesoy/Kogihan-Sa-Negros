import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/helpers/auth_user_role.dart';

abstract final class RouteGuards {
  static bool canAccessAgentRoutes(User? user) {
    return user != null && (isAgentAuthUser(user) || isAdminAuthUser(user));
  }

  static bool canAccessAdminRoutes(User? user) =>
      user != null && isAdminAuthUser(user);
}
