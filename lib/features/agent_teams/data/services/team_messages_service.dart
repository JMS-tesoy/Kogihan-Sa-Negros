import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../messaging/data/services/messaging_service.dart';
import '../models/team_chat_message.dart';
import '../models/team_chat_team.dart';

class TeamMessagesService {
  TeamMessagesService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String teamMessageSelect =
      'id, team_id, sender_id, sender_name, body, created_at, attachment_url, attachment_path, attachment_name, attachment_mime_type, attachment_size_bytes';

  String get currentUserId => _client.auth.currentUser?.id ?? '';

  String get currentUserDisplayName {
    final User? user = _client.auth.currentUser;
    final Map<String, dynamic> data = user?.userMetadata ?? const {};
    final String? fullName = data['full_name'] as String?;
    final String? name = data['name'] as String?;
    final String? email = user?.email;

    return (fullName?.trim().isNotEmpty ?? false)
        ? fullName!.trim()
        : (name?.trim().isNotEmpty ?? false)
        ? name!.trim()
        : (email?.trim().isNotEmpty ?? false)
        ? email!.trim()
        : 'Agent';
  }

  Future<List<TeamChatTeam>> fetchTeams() async {
    final List<dynamic> rows = await _client
        .from('agent_teams')
        .select('id, name, specialization, logo_url')
        .order('name');

    return rows
        .map(
          (row) => TeamChatTeam.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .where((team) => team.id.isNotEmpty)
        .toList();
  }

  Future<List<TeamChatMessage>> fetchMessages({
    required String teamId,
    int limit = 80,
  }) async {
    final List<dynamic> rows = await _client
        .from('team_messages')
        .select(teamMessageSelect)
        .eq('team_id', teamId)
        .order('created_at', ascending: false)
        .limit(limit);

    return rows
        .map(
          (row) =>
              TeamChatMessage.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList()
        .reversed
        .toList();
  }

  Future<TeamChatMessage> sendMessage({
    required String teamId,
    required String body,
    ChatAttachment? attachment,
  }) async {
    final String senderId = currentUserId;
    if (senderId.isEmpty) {
      throw const TeamMessageValidationException(
        'Please sign in again before sending.',
      );
    }

    final String trimmedBody = body.trim();
    if (trimmedBody.isEmpty && attachment == null) {
      throw const TeamMessageValidationException('Message cannot be empty.');
    }

    if (trimmedBody.length > 1000) {
      throw const TeamMessageValidationException(
        'Message is too long. Maximum is 1000 characters.',
      );
    }

    final String bodyToSend = trimmedBody.isNotEmpty
        ? trimmedBody
        : attachment != null
        ? 'Sent an attachment'
        : '';

    final Map<String, dynamic> insertPayload = <String, dynamic>{
      'team_id': teamId,
      'sender_id': senderId,
      'sender_name': currentUserDisplayName,
      'body': bodyToSend,
      if (attachment != null) ...attachment.toMessageColumns(),
    };

    final Map<String, dynamic> row = await _client
        .from('team_messages')
        .insert(insertPayload)
        .select(teamMessageSelect)
        .single();

    return TeamChatMessage.fromMap(row);
  }

  RealtimeChannel subscribeToTeamMessages({
    required String teamId,
    required void Function() onChanged,
  }) {
    return _client
        .channel('team-inbox-$teamId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'team_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: teamId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  Future<void> removeChannel(RealtimeChannel channel) {
    return _client.removeChannel(channel);
  }
}

class TeamMessageValidationException implements Exception {
  const TeamMessageValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
