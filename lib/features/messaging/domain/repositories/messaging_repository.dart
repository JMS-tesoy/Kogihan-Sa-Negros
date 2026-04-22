import '../entities/conversation_entity.dart';
import '../entities/message_entity.dart';

abstract interface class MessagingRepository {
  Future<List<ConversationEntity>> getConversations();

  Future<List<MessageEntity>> getMessages(String conversationId);

  Future<void> sendMessage(MessageEntity message);

  Future<void> markMessageRead(String messageId);
}
