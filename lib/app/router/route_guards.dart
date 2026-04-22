import '../../core/enums/user_role.dart';
import '../state/app_session.dart';

abstract final class RouteGuards {
  static bool canAccessAgentRoutes(AppSession session) {
    return session.user?.role == UserRole.agent ||
        session.user?.role == UserRole.admin;
  }

  static bool canAccessAdminRoutes(AppSession session) {
    return session.user?.role == UserRole.admin;
  }
}
