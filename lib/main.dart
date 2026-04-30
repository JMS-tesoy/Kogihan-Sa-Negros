import 'package:flutter/material.dart';

import 'app/bootstrap/legacy_app_bootstrap.dart';
import 'app/legacy_app_shell.dart';
import 'app/real_estate_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeLegacyAppBootstrap();
  runApp(const RealEstateApp(home: LoginPage()));
}
