import '../../../../core/enums/message_type.dart';

class MessageEntity {
  const MessageEntity({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.body,
    this.type = MessageType.text,
    this.sentAt,
    this.isRead = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String body;
  final MessageType type;
  final DateTime? sentAt;
  final bool isRead;
}
