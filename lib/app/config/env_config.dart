import 'package:flutter_dotenv/flutter_dotenv.dart';

abstract final class EnvConfig {
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get mapboxAccessToken =>
      dotenv.env['MAPBOX_ACCESS_TOKEN'] ?? '';

  static String get googlePlayPackageName =>
      dotenv.env['GOOGLE_PLAY_PACKAGE_NAME'] ?? 'com.landfinder.app';

  // Google Play SKU IDs
  static String get googlePlayMonthlySku =>
      dotenv.env['GOOGLE_PLAY_MONTHLY_SKU'] ?? '';
  static String get googlePlayYearlySku =>
      dotenv.env['GOOGLE_PLAY_YEARLY_SKU'] ?? '';

  // App Store Product IDs
  static String get appStoreMonthlySku =>
      dotenv.env['APP_STORE_MONTHLY_SKU'] ?? '';
  static String get appStoreYearlySku =>
      dotenv.env['APP_STORE_YEARLY_SKU'] ?? '';
}
