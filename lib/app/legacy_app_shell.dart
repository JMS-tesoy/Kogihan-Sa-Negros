import 'package:flutter/material.dart';

import '../features/agent/presentation/screens/agent_dashboard_screen.dart';
import '../features/auth/presentation/navigation/auth_navigation.dart';
import '../features/auth/presentation/screens/login_page.dart';
import '../features/home/presentation/screens/home_page.dart';
import '../features/map/presentation/screens/map_tab.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegacyHomePage(
      mapTabBuilder: (context, savedProperties, onToggleSave) {
        return MapTab(
          savedProperties: savedProperties,
          onToggleSave: onToggleSave,
        );
      },
      onLogout: _signOutAndReturnToLegacyLogin,
    );
  }
}

Future<void> _signOutAndReturnToLegacyLogin(BuildContext context) {
  return signOutAndReturnToLogin(
    context,
    loginBuilder: (context) => const LoginPage(),
  );
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LegacyLoginPage(
      loginBuilder: (context) => const LoginPage(),
      homeBuilder: (context) => const HomePage(),
      adminBuilder: (context) =>
          AdminHomePage(onLogout: _signOutAndReturnToLegacyLogin),
    );
  }
}
