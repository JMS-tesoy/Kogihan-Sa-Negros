import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/agent/data/services/agent_property_service.dart';
import 'package:kogihan_sa_negros/features/agent_teams/data/services/team_messages_service.dart';
import 'package:kogihan_sa_negros/features/messaging/data/services/messaging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpServer server;
  late SupabaseClient client;
  Completer<void>? conversationGate;
  Completer<void>? conversationRequested;
  HttpOverrides? previousHttpOverrides;
  final List<String> propertyFilters = <String>[];

  String jwt(String userId) {
    String encode(Object value) =>
        base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
    return '${encode({'alg': 'none'})}.'
        '${encode({'sub': userId, 'exp': 4102444800})}.signature';
  }

  setUpAll(() async {
    previousHttpOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      final String path = request.uri.path;
      if (path == '/auth/v1/token') {
        final Map<String, dynamic> body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        final String id = (body['email'] as String).split('@').first;
        request.response.write(
          jsonEncode({
            'access_token': jwt(id),
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'refresh-$id',
            'user': {
              'id': id,
              'aud': 'authenticated',
              'role': 'authenticated',
              'email': '$id@example.test',
              'created_at': '2024-01-01T00:00:00Z',
              'app_metadata': {'role': 'agent'},
              'user_metadata': <String, Object>{},
            },
          }),
        );
      } else if (path == '/rest/v1/properties') {
        final String filter = request.uri.queryParameters['agent_id'] ?? '';
        propertyFilters.add(filter);
        final int start = int.parse(
          request.uri.queryParameters['offset'] ?? '0',
        );
        final int count = filter == 'eq.agent-a' ? 101 : 1;
        request.response.write(
          jsonEncode([
            for (int i = start; i < count && i < start + 100; i++)
              {'id': '$filter-$i', 'agent_id': filter.substring(3)},
          ]),
        );
      } else if (path == '/rest/v1/team_members') {
        final String filter = request.uri.queryParameters['user_id'] ?? '';
        request.response.write(
          jsonEncode([
            {'team_id': filter == 'eq.agent-a' ? 'team-a' : 'team-b'},
          ]),
        );
      } else if (path == '/rest/v1/agent_teams') {
        final String filter = request.uri.queryParameters['id'] ?? '';
        request.response.write(
          jsonEncode([
            if (filter.contains('team-a')) {'id': 'team-a', 'name': 'Team A'},
            if (filter.contains('team-b')) {'id': 'team-b', 'name': 'Team B'},
          ]),
        );
      } else if (path == '/rest/v1/conversations') {
        final String filter = request.uri.queryParameters['or'] ?? '';
        if (conversationGate != null) {
          conversationRequested?.complete();
          await conversationGate!.future;
        }
        final String id = filter.contains('agent-a') ? 'agent-a' : 'agent-b';
        request.response.write(
          jsonEncode([
            {
              'id': 'conversation-$id',
              'buyer_id': 'buyer',
              'agent_id': id,
              'messages': <Object>[],
            },
          ]),
        );
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('{}');
      }
      await request.response.close();
    });
    await Supabase.initialize(
      url: 'http://${server.address.address}:${server.port}',
      anonKey: 'test-key',
    );
    client = Supabase.instance.client;
  });

  tearDownAll(() async {
    await client.dispose();
    await server.close(force: true);
    HttpOverrides.global = previousHttpOverrides;
  });

  Future<void> signIn(String id) async {
    await client.auth.signInWithPassword(
      email: '$id@example.test',
      password: 'test-password',
    );
  }

  test('loads all and only the signed-in agent properties', () async {
    await signIn('agent-a');
    final properties = await AgentPropertyService.fetchMyProperties();
    expect(properties, hasLength(101));
    expect(
      properties.every((property) => property.agentId == 'agent-a'),
      isTrue,
    );
    expect(propertyFilters, <String>['eq.agent-a', 'eq.agent-a']);

    await signIn('agent-b');
    final otherProperties = await AgentPropertyService.fetchMyProperties();
    expect(otherProperties, hasLength(1));
    expect(otherProperties.single.agentId, 'agent-b');
  });

  test('team inbox lists only the signed-in agent memberships', () async {
    await signIn('agent-a');
    expect((await TeamMessagesService().fetchTeams()).single.id, 'team-a');
    await signIn('agent-b');
    expect((await TeamMessagesService().fetchTeams()).single.id, 'team-b');
  });

  test(
    'clears message summaries on account change and rejects stale results',
    () async {
      await signIn('agent-a');
      await MessagingService.fetchMyConversationSummaries();
      expect(
        MessagingService.getCachedConversationSummaries().single.agentId,
        'agent-a',
      );
      conversationGate = Completer<void>();
      conversationRequested = Completer<void>();
      final Future<List<ConversationSummary>> pending =
          MessagingService.fetchMyConversationSummaries();
      await conversationRequested!.future;
      await signIn('agent-b');
      expect(MessagingService.getCachedConversationSummaries(), isEmpty);
      conversationGate!.complete();
      await expectLater(pending, throwsStateError);
      conversationGate = null;
      await MessagingService.fetchMyConversationSummaries();
      expect(
        MessagingService.getCachedConversationSummaries().single.agentId,
        'agent-b',
      );
    },
  );
}
