import 'env_config.dart';

abstract final class SupabaseConfig {
  static const fallbackUrl = 'https://vludvvjkrrqzjahxjdjl.supabase.co';
  static const fallbackAnonKey =
      'sb_publishable_xrlYmyU6k2ItwhoSycq_iQ_4RxiPGdJ';

  static String get url => EnvConfig.supabaseUrl;
  static String get anonKey => EnvConfig.supabaseAnonKey;
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
  static String get effectiveUrl => url.isNotEmpty ? url : fallbackUrl;
  static String get effectiveAnonKey =>
      anonKey.isNotEmpty ? anonKey : fallbackAnonKey;
  static const profileAvatarsBucket = 'profile-avatars';
}
