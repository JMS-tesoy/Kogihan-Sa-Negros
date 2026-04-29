import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/storage_constants.dart';

final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(
  ThemeMode.system,
);
final ValueNotifier<double> appFontScaleNotifier = ValueNotifier(1.0);

Future<void> initializeAppThemePreference() async {
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final bool followSystemTheme =
      preferences.getBool(StorageConstants.followSystemThemeEnabled) ?? true;
  final String? preferredThemeMode = preferences.getString(
    StorageConstants.preferredThemeMode,
  );
  appThemeNotifier.value = followSystemTheme
      ? ThemeMode.system
      : (preferredThemeMode == 'dark' ? ThemeMode.dark : ThemeMode.light);
}

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
