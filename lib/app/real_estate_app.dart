import 'package:flutter/material.dart';

import 'state/app_display_preferences.dart'
    show appFontScaleNotifier, appThemeNotifier;
import 'theme/legacy_app_theme.dart';

class RealEstateApp extends StatelessWidget {
  final Widget home;

  const RealEstateApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentMode, child) {
        return ValueListenableBuilder<double>(
          valueListenable: appFontScaleNotifier,
          builder: (context, fontScale, child) {
            return MaterialApp(
              title: 'Land Finder',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              themeAnimationDuration: const Duration(milliseconds: 220),
              themeAnimationCurve: Curves.easeOutCubic,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(fontScale)),
                  child: child!,
                );
              },
              theme: buildLegacyLightTheme(),
              darkTheme: buildLegacyDarkTheme(),
              home: home,
            );
          },
        );
      },
    );
  }
}
