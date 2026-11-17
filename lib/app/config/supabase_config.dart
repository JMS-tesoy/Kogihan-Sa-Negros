import 'env_config.dart';

abstract final class SupabaseConfig {
  /// Supabase URL from environment configuration
  /// MUST be set via .env file. No fallback credentials allowed for security.
  static String get url {
    final url = EnvConfig.supabaseUrl;
    if (url.isEmpty) {
      throw Exception(
        'SUPABASE_URL not configured. '
        'Set SUPABASE_URL in .env file before running app.'
      );
    }
    return url;
  }

  /// Supabase anonymous key from environment configuration
  /// MUST be set via .env file. No fallback credentials allowed for security.
  static String get anonKey {
    final key = EnvConfig.supabaseAnonKey;
    if (key.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY not configured. '
        'Set SUPABASE_ANON_KEY in .env file before running app.'
      );
    }
    return key;
  }

  /// Alias for url (for compatibility with existing code)
  static String get effectiveUrl => url;

  /// Alias for anonKey (for compatibility with existing code)
  static String get effectiveAnonKey => anonKey;

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
  static const profileAvatarsBucket = 'profile-avatars';
}
