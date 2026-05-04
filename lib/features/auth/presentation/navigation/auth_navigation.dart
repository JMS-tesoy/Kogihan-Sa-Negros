import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/app_config.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import '../../../properties/presentation/widgets/property_image.dart';
import '../../data/services/auth_session_service.dart';
import '../../domain/helpers/auth_user_role.dart';
import '../screens/change_password_screen.dart';

Future<void> signOutAndReturnToLogin(
  BuildContext context, {
  required WidgetBuilder loginBuilder,
}) async {
  try {
    await AuthSessionService.signOutCurrentUser();

    if (!context.mounted) {
      return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: loginBuilder),
      (route) => false,
    );
  } catch (_) {
    if (!context.mounted) {
      return;
    }

    AppSnackBar.error(context, 'Failed to log out. Please try again.');
  }
}

Future<void> openPasswordRecoveryPage(
  BuildContext context, {
  required WidgetBuilder loginBuilder,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChangePasswordPage(
        isPasswordRecovery: true,
        recoveryLoginBuilder: loginBuilder,
      ),
    ),
  );
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
