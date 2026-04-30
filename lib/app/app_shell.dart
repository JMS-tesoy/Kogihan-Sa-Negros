import 'package:flutter/material.dart';

import '../features/agent/presentation/screens/agent_dashboard_screen.dart';
import '../features/auth/presentation/navigation/auth_navigation.dart';
import '../features/auth/presentation/screens/login_page.dart';
import '../features/home/presentation/screens/home_page.dart';
import '../features/map/presentation/screens/map_tab.dart';

class AppHomePage extends StatelessWidget {
  const AppHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return HomePageView(
      mapTabBuilder: (context, savedProperties, onToggleSave) {
        return MapTab(
          savedProperties: savedProperties,
          onToggleSave: onToggleSave,
        );
      },
      onLogout: _signOutAndReturnToLogin,
    );
  }
}

Future<void> _signOutAndReturnToLogin(BuildContext context) {
  return signOutAndReturnToLogin(
    context,
    loginBuilder: (context) => const AppLoginPage(),
  );
}

class AppLoginPage extends StatelessWidget {
  const AppLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LoginPageView(
      loginBuilder: (context) => const AppLoginPage(),
      homeBuilder: (context) => const AppHomePage(),
      adminBuilder: (context) =>
          AdminHomePage(onLogout: _signOutAndReturnToLogin),
    );
  }
}
