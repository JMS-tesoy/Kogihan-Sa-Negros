import 'env_config.dart';

abstract final class MapboxConfig {
  static String get accessToken => EnvConfig.mapboxAccessToken;
  static bool get isConfigured => accessToken.isNotEmpty;
}
