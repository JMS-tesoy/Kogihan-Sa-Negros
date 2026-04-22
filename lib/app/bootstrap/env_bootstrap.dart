import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class EnvBootstrap {
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Local development can still start when .env is not present yet.
    }
  }
}
