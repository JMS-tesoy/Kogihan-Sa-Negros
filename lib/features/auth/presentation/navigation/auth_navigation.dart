import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/router/route_names.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import '../../../properties/presentation/widgets/property_image.dart';
import '../../data/services/auth_session_service.dart';
import '../../domain/helpers/auth_user_role.dart';

Future<void> signOutAndReturnToLogin(
  BuildContext context, {
  required WidgetBuilder loginBuilder,
}) async {
  await _signOutAndNavigateToLogin(context, () {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: loginBuilder),
      (route) => false,
    );
  });
}

Future<void> signOutAndReturnToLoginRoute(BuildContext context) {
  return _signOutAndNavigateToLogin(context, () {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
  });
}

Future<void> _signOutAndNavigateToLogin(
  BuildContext context,
  VoidCallback navigateToLogin,
) async {
  try {
    await AuthSessionService.signOutCurrentUser();

    if (!context.mounted) {
      return;
    }

    navigateToLogin();
  } catch (_) {
    if (!context.mounted) {
      return;
    }

    AppSnackBar.error(context, 'Failed to log out. Please try again.');
  }
}

Future<void> replaceWithAuthenticatedHome(
  BuildContext context, {
  required WidgetBuilder homeBuilder,
}) {
  return Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: homeBuilder),
  );
}

Future<void> replaceWithAuthenticatedAdmin(
  BuildContext context, {
  required WidgetBuilder adminBuilder,
}) {
  return Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: adminBuilder),
  );
}

Future<void> routeAuthenticatedUser(
  BuildContext context, {
  required User user,
  required WidgetBuilder adminBuilder,
  required WidgetBuilder agentBuilder,
  required WidgetBuilder homeBuilder,
}) async {
  await loadProperties();

  if (!context.mounted) {
    return;
  }

  if (isAdminAuthUser(user)) {
    await replaceWithAuthenticatedAdmin(context, adminBuilder: adminBuilder);
    return;
  }

  if (isAgentAuthUser(user)) {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: agentBuilder),
    );
    return;
  }

  await precacheInitialPropertyImages(
    context: context,
    properties: appPropertiesNotifier.value,
    count: AppConfig.initialPropertyImagePrefetchCount,
  );

  if (!context.mounted) {
    return;
  }

  await replaceWithAuthenticatedHome(context, homeBuilder: homeBuilder);
}
