import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kogihan_sa_negros/app/config/auth_config.dart';
import 'package:kogihan_sa_negros/app/router/route_guards.dart';
import 'package:kogihan_sa_negros/features/auth/domain/helpers/auth_user_role.dart';

void main() {
  setUp(() {
    dotenv.testLoad(
      fileInput: '''
DEV_AGENT_EMAIL=agent@example.com
DEV_AGENT_PASSWORD=test-password
''',
    );
  });

  test('a configured development account is not trusted as an Agent', () {
    final User user = _user(email: 'AGENT@example.com');

    expect(AuthConfig.hasDevAgentCredentials, isTrue);
    expect(isAgentAuthUser(user), isFalse);
  });

  test('uses app metadata for non-development Agent accounts', () {
    final User user = _user(
      email: 'agent@example.com',
      appMetadata: const <String, dynamic>{'role': 'agent'},
    );

    expect(isAgentAuthUser(user), isTrue);
  });

  test('does not trust user metadata as an Agent role', () {
    final User user = _user(
      email: 'someone-else@example.com',
      userMetadata: const <String, dynamic>{'role': 'agent'},
    );

    expect(isAgentAuthUser(user), isFalse);
  });

  test('route guards grant access only to trusted app metadata roles', () {
    final User agent = _user(
      appMetadata: const <String, dynamic>{'role': 'agent'},
    );
    final User admin = _user(
      appMetadata: const <String, dynamic>{'role': 'admin'},
    );
    final User clientClaimedAdmin = _user(
      userMetadata: const <String, dynamic>{'role': 'admin'},
    );

    expect(RouteGuards.canAccessAgentRoutes(agent), isTrue);
    expect(RouteGuards.canAccessAgentRoutes(admin), isTrue);
    expect(RouteGuards.canAccessAdminRoutes(admin), isTrue);
    expect(RouteGuards.canAccessAdminRoutes(agent), isFalse);
    expect(RouteGuards.canAccessAdminRoutes(clientClaimedAdmin), isFalse);
    expect(RouteGuards.canAccessAgentRoutes(null), isFalse);
  });
}

User _user({
  String? email,
  Map<String, dynamic> appMetadata = const <String, dynamic>{},
  Map<String, dynamic> userMetadata = const <String, dynamic>{},
}) {
  return User.fromJson(<String, dynamic>{
        'id': 'test-user-id',
        'aud': 'authenticated',
        'email': email,
        'app_metadata': appMetadata,
        'user_metadata': userMetadata,
        'created_at': '2026-01-01T00:00:00.000Z',
      }) ??
      (throw StateError('The test user fixture must parse successfully.'));
}
