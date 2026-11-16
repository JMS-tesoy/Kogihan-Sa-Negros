import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/widgets/app_background.dart';
import '../features/auth/data/services/auth_session_service.dart';
import '../features/auth/presentation/screens/change_password_screen.dart';
import 'app_shell.dart';
import 'router/app_router.dart';
import 'state/app_display_preferences.dart'
    show appFontScaleNotifier, appStarryBackgroundNotifier, appThemeNotifier;
import 'theme/land_finder_app_theme.dart';

class LandFinderApp extends StatefulWidget {
  final Widget home;

  const LandFinderApp({super.key, required this.home});

  @override
  State<LandFinderApp> createState() => _LandFinderAppState();
}

class _LandFinderAppState extends State<LandFinderApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authRecoverySubscription;
  bool _isOpeningPasswordRecovery = false;

  @override
  void initState() {
    super.initState();
    _authRecoverySubscription = AuthSessionService.listenForPasswordRecovery(
      onPasswordRecovery: _openPasswordRecoveryPage,
    );
  }

  @override
  void dispose() {
    _authRecoverySubscription?.cancel();
    super.dispose();
  }

  Future<void> _openPasswordRecoveryPage() async {
    if (_isOpeningPasswordRecovery) return;

    _isOpeningPasswordRecovery = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final NavigatorState? navigator = _navigatorKey.currentState;
      if (navigator == null) {
        _isOpeningPasswordRecovery = false;
        return;
      }

      unawaited(
        navigator
            .push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ChangePasswordPage(
                  isPasswordRecovery: true,
                  recoveryLoginBuilder: (_) => const AppLoginPage(),
                ),
              ),
            )
            .then<void>((_) {
              if (mounted) {
                _isOpeningPasswordRecovery = false;
              }
            }),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentMode, child) {
        return ValueListenableBuilder<double>(
          valueListenable: appFontScaleNotifier,
          builder: (context, fontScale, child) {
            final double safeFontScale = fontScale.clamp(0.9, 1.15).toDouble();
            return MaterialApp(
              navigatorKey: _navigatorKey,
              title: 'Land Finder',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              themeAnimationDuration: const Duration(milliseconds: 220),
              themeAnimationCurve: Curves.easeOutCubic,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(safeFontScale)),
                  child: ValueListenableBuilder<bool>(
                    valueListenable: appStarryBackgroundNotifier,
                    builder: (context, starryBackgroundEnabled, child) {
                      return AppBackground(
                        enabled: starryBackgroundEnabled,
                        child: child!,
                      );
                    },
                    child: child!,
                  ),
                );
              },
              theme: buildLandFinderLightTheme(),
              darkTheme: buildLandFinderDarkTheme(),
              onGenerateRoute: AppRouter.onGenerateRoute,
              home: widget.home,
            );
          },
        );
      },
    );
  }
}
