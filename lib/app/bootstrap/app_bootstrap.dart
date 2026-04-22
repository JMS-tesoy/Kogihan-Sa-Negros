import 'package:flutter/widgets.dart';

import '../app.dart';
import 'env_bootstrap.dart';
import 'service_bootstrap.dart';

abstract final class AppBootstrap {
  static Future<Widget> createApp() async {
    await EnvBootstrap.load();
    await ServiceBootstrap.initialize();

    return const RealEstateApp();
  }
}
