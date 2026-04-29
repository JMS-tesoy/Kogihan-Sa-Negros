abstract final class AuthConfig {
  static const redirectUrl =
      'com.example.flutterapplication1://login-callback/';

  static const devAgentShortcutUsername = '1q1q';
  static const devAgentShortcutPassword = '1q1q';
  static const devAgentEmail = String.fromEnvironment('DEV_AGENT_EMAIL');
  static const devAgentPassword = String.fromEnvironment('DEV_AGENT_PASSWORD');

  static const devUserShortcutUsername = '2q2q';
  static const devUserShortcutPassword = '2q2q';
  static const devUserEmail = String.fromEnvironment('DEV_USER_EMAIL');
  static const devUserPassword = String.fromEnvironment('DEV_USER_PASSWORD');

  static bool get hasDevAgentCredentials =>
      devAgentEmail.isNotEmpty && devAgentPassword.isNotEmpty;

  static bool get hasDevUserCredentials =>
      devUserEmail.isNotEmpty && devUserPassword.isNotEmpty;
}
