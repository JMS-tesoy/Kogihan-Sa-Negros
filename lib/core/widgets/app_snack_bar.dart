import 'package:flutter/material.dart';

enum AppSnackBarType {
  success,
  error,
  warning,
  info,
}

class AppSnackBar {
  const AppSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    AppSnackBarType type = AppSnackBarType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final _SnackBarStyle style = _styleForType(colorScheme, type);

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            Icon(
              style.icon,
              color: style.foregroundColor,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: style.foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: style.backgroundColor,
        elevation: 8,
        duration: duration,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        dismissDirection: DismissDirection.horizontal,
      ),
    );
  }

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      type: AppSnackBarType.success,
      duration: duration,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    show(
      context,
      message: message,
      type: AppSnackBarType.error,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      type: AppSnackBarType.warning,
      duration: duration,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
  }) {
    show(
      context,
      message: message,
      type: AppSnackBarType.info,
      duration: duration,
    );
  }

  static _SnackBarStyle _styleForType(
    ColorScheme colorScheme,
    AppSnackBarType type,
  ) {
    switch (type) {
      case AppSnackBarType.success:
        return const _SnackBarStyle(
          icon: Icons.check_circle_outline_rounded,
          backgroundColor: Color(0xFF116B3A),
          foregroundColor: Colors.white,
        );

      case AppSnackBarType.error:
        return _SnackBarStyle(
          icon: Icons.error_outline_rounded,
          backgroundColor: colorScheme.error,
          foregroundColor: colorScheme.onError,
        );

      case AppSnackBarType.warning:
        return const _SnackBarStyle(
          icon: Icons.warning_amber_rounded,
          backgroundColor: Color(0xFF8A5A00),
          foregroundColor: Colors.white,
        );

      case AppSnackBarType.info:
        return _SnackBarStyle(
          icon: Icons.info_outline_rounded,
          backgroundColor: colorScheme.inverseSurface,
          foregroundColor: colorScheme.onInverseSurface,
        );
    }
  }
}

class _SnackBarStyle {
  const _SnackBarStyle({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
}