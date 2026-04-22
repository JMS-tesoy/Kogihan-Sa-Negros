import 'env_config.dart';

abstract final class SupabaseConfig {
  static String get url => EnvConfig.supabaseUrl;
  static String get anonKey => EnvConfig.supabaseAnonKey;
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
