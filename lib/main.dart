import 'package:flutter/material.dart';

import 'app/bootstrap/land_finder_app_bootstrap.dart';
import 'app/land_finder_app.dart';
import 'features/splash/presentation/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeLandFinderAppBootstrap();
  runApp(const LandFinderApp(home: SplashScreen()));
}
