import 'package:flutter/material.dart';

import 'app/bootstrap/land_finder_app_bootstrap.dart';
import 'app/app_shell.dart';
import 'app/land_finder_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeLandFinderAppBootstrap();
  runApp(const LandFinderApp(home: AppLoginPage()));
}
