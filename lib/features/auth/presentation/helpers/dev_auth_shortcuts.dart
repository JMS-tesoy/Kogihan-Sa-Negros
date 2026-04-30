import '../../../../app/config/auth_config.dart';

enum DevAuthShortcutType { none, agent, user }

class DevAuthShortcutResult {
  final DevAuthShortcutType type;
  final bool hasCredentials;

  const DevAuthShortcutResult({
    required this.type,
    required this.hasCredentials,
  });

  bool get isAgent => type == DevAuthShortcutType.agent && hasCredentials;
  bool get isUser => type == DevAuthShortcutType.user && hasCredentials;

  String emailFor(String enteredEmail) {
    return isAgent ? AuthConfig.devAgentEmail : enteredEmail;
  }

  String passwordFor(String enteredPassword) {
    return isAgent ? AuthConfig.devAgentPassword : enteredPassword;
  }

  String? get disabledMessage {
    if (hasCredentials) return null;

    return switch (type) {
      DevAuthShortcutType.agent =>
        'Dev agent shortcut is disabled until DEV_AGENT_EMAIL and DEV_AGENT_PASSWORD are provided.',
      DevAuthShortcutType.user =>
        'Dev user shortcut is disabled until DEV_USER_EMAIL and DEV_USER_PASSWORD are provided.',
      DevAuthShortcutType.none => null,
    };
  }
}

DevAuthShortcutResult devAuthShortcutForCredentials({
  required String email,
  required String password,
}) {
  if (email == AuthConfig.devAgentShortcutUsername &&
      password == AuthConfig.devAgentShortcutPassword) {
    return DevAuthShortcutResult(
      type: DevAuthShortcutType.agent,
      hasCredentials: AuthConfig.hasDevAgentCredentials,
    );
  }

  if (email == AuthConfig.devUserShortcutUsername &&
      password == AuthConfig.devUserShortcutPassword) {
    return DevAuthShortcutResult(
      type: DevAuthShortcutType.user,
      hasCredentials: AuthConfig.hasDevUserCredentials,
    );
  }

  return const DevAuthShortcutResult(
    type: DevAuthShortcutType.none,
    hasCredentials: false,
  );
}
