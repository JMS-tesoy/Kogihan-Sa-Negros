import 'package:flutter/material.dart';

abstract final class AppBottomSheet {
  static Future<T?> showAppSheet<T>({
    required BuildContext context,
    required Widget child,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (_) => SafeArea(child: child),
    );
  }
}
