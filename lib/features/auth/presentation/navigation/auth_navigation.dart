import 'package:flutter/material.dart';

import '../../data/services/auth_session_service.dart';
import '../screens/change_password_screen.dart';

Future<void> signOutAndReturnToLogin(
  BuildContext context, {
  required WidgetBuilder loginBuilder,
}) async {
  try {
    await AuthSessionService.signOutCurrentUser();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: loginBuilder),
      (route) => false,
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to log out. Please try again.')),
    );
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
