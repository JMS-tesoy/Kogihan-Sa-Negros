import 'package:flutter/material.dart';

import 'app/bootstrap/app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final app = await AppBootstrap.createApp();
  runApp(app);
}
