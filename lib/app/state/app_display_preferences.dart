import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_constants.dart';

final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(
  ThemeMode.system,
);
final ValueNotifier<double> appFontScaleNotifier = ValueNotifier(1.0);

Future<void> persistFollowSystemThemePreference(bool enabled) async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setBool(StorageConstants.followSystemThemeEnabled, enabled);
}

Future<void> persistPreferredThemeMode(ThemeMode themeMode) async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  await preferences.setString(
    StorageConstants.preferredThemeMode,
    themeMode == ThemeMode.dark ? 'dark' : 'light',
  );
}

class AppDisplayPreferences {
  const AppDisplayPreferences._();

  static Future<void> persistFollowSystemThemePreference(bool enabled) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setBool(
      StorageConstants.followSystemThemeEnabled,
      enabled,
    );
  }

  static Future<void> persistPreferredThemeMode(ThemeMode themeMode) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      StorageConstants.preferredThemeMode,
      themeMode == ThemeMode.dark ? 'dark' : 'light',
    );
  }
}
