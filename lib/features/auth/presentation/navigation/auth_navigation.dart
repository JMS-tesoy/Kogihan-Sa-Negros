import 'package:flutter/material.dart';

import '../../data/services/auth_session_service.dart';

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
