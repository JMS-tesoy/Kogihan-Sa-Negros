class MapboxConfig {
  MapboxConfig._();

  static const fallbackAccessToken = String.fromEnvironment('ACCESS_TOKEN');

  static String accessToken = fallbackAccessToken;
}
