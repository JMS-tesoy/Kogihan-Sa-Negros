import 'package:supabase_flutter/supabase_flutter.dart';

import 'shared_properties.dart';

class MessagingProfile {
  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String role;

  const MessagingProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
  });

  String get displayName {
    final String name = (fullName ?? '').trim();
    if (name.isNotEmpty) return name;

    final String emailValue = (email ?? '').trim();
    if (emailValue.isNotEmpty) return emailValue;

    final String phoneValue = (phone ?? '').trim();
    if (phoneValue.isNotEmpty) return phoneValue;

    return 'Unknown User';
  }

  factory MessagingProfile.fromMap(Map<String, dynamic> map) {
    return MessagingProfile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      role: (map['role'] as String?) ?? 'user',
    );
  }
}

class ConversationSummary {
  final String id;
  final String buyerId;
  final String agentId;
  final String? propertyId;
  final String subject;
  final String lastMessagePreview;
  final DateTime? lastMessageAt;
  final String otherParticipantId;
  final String otherParticipantName;
  final bool isUnread;
  final String? propertyTitle;

  const ConversationSummary({
    required this.id,
    required this.buyerId,
    required this.agentId,
    required this.propertyId,
    required this.subject,
    required this.lastMessagePreview,
    required this.lastMessageAt,
    required this.otherParticipantId,
    required this.otherParticipantName,
    required this.isUnread,
    required this.propertyTitle,
  });

  String get title {
    if (subject.trim().isNotEmpty) return subject.trim();
    if ((propertyTitle ?? '').trim().isNotEmpty) return propertyTitle!.trim();
    return otherParticipantName;
  }

  factory ConversationSummary.fromMap(
    Map<String, dynamic> map,
    String currentUserId,
  ) {
    final Map<String, dynamic> buyer =
        Map<String, dynamic>.from((map['buyer'] as Map?) ?? const {});
    final Map<String, dynamic> agent =
        Map<String, dynamic>.from((map['agent'] as Map?) ?? const {});
    final Map<String, dynamic> property =
        Map<String, dynamic>.from((map['property'] as Map?) ?? const {});
    final List<dynamic> messageList = (map['messages'] as List?) ?? const [];
    final Map<String, dynamic>? latestMessage = messageList.isEmpty
        ? null
        : Map<String, dynamic>.from(messageList.first as Map);

    final String buyerId = map['buyer_id'] as String;
    final String agentId = map['agent_id'] as String;
    final bool isBuyer = currentUserId == buyerId;
    final Map<String, dynamic> otherParty = isBuyer ? agent : buyer;
    final String otherId = (isBuyer ? agentId : buyerId);
    final String preview = ((map['last_message_preview'] as String?) ?? '').trim();
    final String latestBody = ((latestMessage?['body'] as String?) ?? '').trim();

    return ConversationSummary(
      id: map['id'] as String,
      buyerId: buyerId,
      agentId: agentId,
      propertyId: map['property_id'] as String?,
      subject: ((map['subject'] as String?) ?? '').trim(),
      lastMessagePreview: preview.isNotEmpty ? preview : latestBody,
      lastMessageAt: _parseDateTime(
        map['last_message_at'] ?? latestMessage?['created_at'],
      ),
      otherParticipantId: otherId,
      otherParticipantName: MessagingProfile.fromMap({
        'id': otherId,
        ...otherParty,
      }).displayName,
      isUnread: latestMessage != null &&
          latestMessage['sender_id'] != currentUserId &&
          latestMessage['read_at'] == null,
      propertyTitle: property['title'] as String?,
    );
  }
}

class ConversationMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const ConversationMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });

  bool isFrom(String userId) => senderId == userId;

  factory ConversationMessage.fromMap(Map<String, dynamic> map) {
    return ConversationMessage(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String,
      senderId: map['sender_id'] as String,
      body: (map['body'] as String?) ?? '',
      createdAt: _parseDateTime(map['created_at']) ?? DateTime.now(),
      readAt: _parseDateTime(map['read_at']),
    );
  }
}

class MessagingService {
  MessagingService._();

  static final SupabaseClient _client = Supabase.instance.client;

  static User get _currentUser {
    final User? user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('You must be logged in to use messaging.');
    }
    return user;
  }

  static Future<MessagingProfile?> fetchCurrentProfile() async {
    final User user = _currentUser;
    final Map<String, dynamic>? response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return MessagingProfile.fromMap(response);
  }

  static Future<List<ConversationSummary>> fetchMyConversationSummaries() async {
    final User user = _currentUser;
    final List<dynamic> response = await _client
        .from('conversations')
        .select(
          'id, buyer_id, agent_id, property_id, subject, last_message_preview, '
          'last_message_at, buyer:buyer_id(id, full_name, email, phone, role), '
          'agent:agent_id(id, full_name, email, phone, role), '
          'property:property_id(id, title), '
          'messages(id, sender_id, body, read_at, created_at)',
        )
        .or('buyer_id.eq.${user.id},agent_id.eq.${user.id}')
        .order('last_message_at', ascending: false)
        .order('created_at', ascending: false, referencedTable: 'messages')
        .limit(1, referencedTable: 'messages');

    return response
        .map((item) => ConversationSummary.fromMap(
              Map<String, dynamic>.from(item as Map),
              user.id,
            ))
        .toList();
  }

  static Future<int> fetchMyUnreadConversationCount() async {
    final List<ConversationSummary> summaries = await fetchMyConversationSummaries();
    return summaries.where((summary) => summary.isUnread).length;
  }

  static Future<List<ConversationMessage>> fetchConversationMessages(
    String conversationId,
  ) async {
    final List<dynamic> response = await _client
        .from('messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return response
        .map((item) => ConversationMessage.fromMap(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  static Future<void> markConversationAsRead(String conversationId) async {
    final User user = _currentUser;
    await _client
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', user.id)
        .isFilter('read_at', null);
  }

  static Future<void> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final User user = _currentUser;
    await _client.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': user.id,
      'body': body.trim(),
    });
  }

  static Future<String> startConversationForProperty({
    required Property property,
    required String body,
    required String fullName,
    required String contactValue,
  }) async {
    final User user = _currentUser;
    await _upsertCurrentProfile(
      fullName: fullName,
      contactValue: contactValue,
    );

    final Map<String, dynamic>? agentResponse = await _client
        .from('profiles')
        .select('id, full_name, email, phone, role')
        .or('role.eq.agent,role.eq.admin')
        .neq('id', user.id)
        .order('created_at', ascending: true)
        .limit(1)
        .maybeSingle();

    if (agentResponse == null) {
      throw StateError('No agent account is available yet.');
    }

    final String agentId = agentResponse['id'] as String;
    final Map<String, dynamic>? existingConversation = await _client
        .from('conversations')
        .select('id')
        .eq('buyer_id', user.id)
        .eq('agent_id', agentId)
        .eq('property_id', property.id)
        .limit(1)
        .maybeSingle();

    String conversationId;
    if (existingConversation != null) {
      conversationId = existingConversation['id'] as String;
    } else {
      final Map<String, dynamic> createdConversation = await _client
          .from('conversations')
          .insert({
            'buyer_id': user.id,
            'agent_id': agentId,
            'property_id': property.id,
            'subject': property.title,
          })
          .select('id')
          .single();
      conversationId = createdConversation['id'] as String;
    }

    await sendMessage(conversationId: conversationId, body: body);
    return conversationId;
  }

  static Future<void> _upsertCurrentProfile({
    required String fullName,
    required String contactValue,
  }) async {
    final User user = _currentUser;
    final MessagingProfile? existingProfile = await fetchCurrentProfile();
    final bool isEmailContact = contactValue.contains('@');
    final String normalizedRole = _normalizeRole(
      (user.appMetadata['role'] ?? user.userMetadata?['role']) as String?,
    );

    await _client.from('profiles').upsert({
      'id': user.id,
      'full_name': fullName.trim().isNotEmpty
          ? fullName.trim()
          : existingProfile?.fullName ??
              user.userMetadata?['full_name'] ??
              user.userMetadata?['name'],
      'email': isEmailContact
          ? contactValue.trim()
          : existingProfile?.email ?? user.email,
      'phone': isEmailContact
          ? existingProfile?.phone ?? user.phone
          : contactValue.trim(),
      'role': normalizedRole,
    }, onConflict: 'id');
  }

  static String _normalizeRole(String? role) {
    switch ((role ?? '').toLowerCase()) {
      case 'admin':
        return 'admin';
      case 'agent':
        return 'agent';
      default:
        return 'user';
    }
  }
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
