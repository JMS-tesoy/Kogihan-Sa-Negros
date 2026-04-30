import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide ImageSource, Size;
import '../../features/auth/presentation/navigation/auth_navigation.dart';
import '../../features/auth/presentation/screens/legacy_login_page.dart';
import '../../features/location/data/datasources/negros_places_datasource.dart';
import '../../features/agent/presentation/screens/agent_dashboard_screen.dart';
import '../../features/home/presentation/screens/legacy_home_page.dart';
import '../../features/properties/data/datasources/shared_properties.dart';
import '../../features/properties/presentation/screens/property_details_inline_screen.dart';
import '../../features/properties/presentation/widgets/property_image.dart';
import '../real_estate_app.dart';
import '../bootstrap/legacy_app_bootstrap.dart';
import '../config/app_config.dart';
import '../config/mapbox_config.dart';
import '../router/instant_route.dart';

part '../../features/map/presentation/screens/legacy_map_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeLegacyAppBootstrap();
  runApp(const RealEstateApp(home: LoginPage()));
}

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


