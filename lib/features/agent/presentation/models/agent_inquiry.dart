import '../../../messaging/data/services/messaging_service.dart';

enum AgentInboxFilter { all, unread }

String formatInboxTime(DateTime? value) {
  if (value == null) return '';

  final DateTime localValue = value.toLocal();
  final DateTime now = DateTime.now();
  final Duration difference = now.difference(localValue);

  if (difference.inDays == 0) {
    final int hour = localValue.hour % 12 == 0 ? 12 : localValue.hour % 12;
    final String minute = localValue.minute.toString().padLeft(2, '0');
    final String suffix = localValue.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  if (difference.inDays == 1) return 'Yesterday';

  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[localValue.month - 1]} ${localValue.day}';
}

List<AgentInquiry> cachedAgentInquiries() {
  final List<ConversationSummary> cachedSummaries =
      MessagingService.getCachedConversationSummaries();
  if (cachedSummaries.isEmpty) return const [];
  return AgentInquiry.groupedFromConversationSummaries(cachedSummaries);
}

class AgentInquiry {
  final String id;
  final String buyerId;
  final String buyerName;
  final String message;
  final String timeLabel;
  final bool isUnread;
  final String conversationTitle;
  final String primaryConversationId;
  final List<String> conversationIds;
  final DateTime? lastMessageAt;

  const AgentInquiry({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.message,
    required this.timeLabel,
    required this.isUnread,
    required this.conversationTitle,
    required this.primaryConversationId,
    required this.conversationIds,
    required this.lastMessageAt,
  });

  AgentInquiry copyWith({
    String? id,
    String? buyerId,
    String? buyerName,
    String? message,
    String? timeLabel,
    bool? isUnread,
    String? conversationTitle,
    String? primaryConversationId,
    List<String>? conversationIds,
    DateTime? lastMessageAt,
  }) {
    return AgentInquiry(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      message: message ?? this.message,
      timeLabel: timeLabel ?? this.timeLabel,
      isUnread: isUnread ?? this.isUnread,
      conversationTitle: conversationTitle ?? this.conversationTitle,
      primaryConversationId:
          primaryConversationId ?? this.primaryConversationId,
      conversationIds: conversationIds ?? this.conversationIds,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  factory AgentInquiry.fromConversationSummary(ConversationSummary summary) {
    return AgentInquiry(
      id: summary.otherParticipantId,
      buyerId: summary.otherParticipantId,
      buyerName: summary.otherParticipantName,
      message: summary.lastMessagePreview.isNotEmpty
          ? summary.lastMessagePreview
          : 'No messages yet.',
      timeLabel: formatInboxTime(summary.lastMessageAt),
      isUnread: summary.isUnread,
      conversationTitle: summary.title,
      primaryConversationId: summary.id,
      conversationIds: [summary.id],
      lastMessageAt: summary.lastMessageAt,
    );
  }

  static List<AgentInquiry> groupedFromConversationSummaries(
    List<ConversationSummary> summaries,
  ) {
    final Map<String, List<ConversationSummary>> grouped = {};

    for (final ConversationSummary summary in summaries) {
      grouped.putIfAbsent(summary.otherParticipantId, () => []).add(summary);
    }

    final List<AgentInquiry> inquiries = grouped.values.map((items) {
      items.sort((a, b) {
        final DateTime? first = a.lastMessageAt;
        final DateTime? second = b.lastMessageAt;
        if (first == null && second == null) return 0;
        if (first == null) return 1;
        if (second == null) return -1;
        return second.compareTo(first);
      });

      final ConversationSummary latest = items.first;
      final List<String> titles = items
          .map((summary) => summary.title.trim())
          .where((title) => title.isNotEmpty)
          .toSet()
          .toList();

      return AgentInquiry(
        id: latest.otherParticipantId,
        buyerId: latest.otherParticipantId,
        buyerName: latest.otherParticipantName,
        message: latest.lastMessagePreview.isNotEmpty
            ? latest.lastMessagePreview
            : 'No messages yet.',
        timeLabel: formatInboxTime(latest.lastMessageAt),
        isUnread: items.any((summary) => summary.isUnread),
        conversationTitle: titles.length <= 1
            ? latest.title
            : 'Multiple inquiries',
        primaryConversationId: latest.id,
        conversationIds: items.map((summary) => summary.id).toList(),
        lastMessageAt: latest.lastMessageAt,
      );
    }).toList();

    inquiries.sort((a, b) {
      final DateTime? first = a.lastMessageAt;
      final DateTime? second = b.lastMessageAt;
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });

    return inquiries;
  }
}
