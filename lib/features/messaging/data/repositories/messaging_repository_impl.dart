import '../../domain/entities/conversation_entity.dart';
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/messaging_repository.dart';
import '../datasources/messaging_remote_datasource.dart';
import '../models/message_model.dart';

class MessagingRepositoryImpl implements MessagingRepository {
  MessagingRepositoryImpl({MessagingRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? MessagingRemoteDatasource();

  final MessagingRemoteDatasource _remoteDatasource;

  @override
  Future<List<ConversationEntity>> getConversations() {
    return _remoteDatasource.getConversations();
  }

  @override
  Future<List<MessageEntity>> getMessages(String conversationId) {
    return _remoteDatasource.getMessages(conversationId);
  }

  @override
  Future<void> markMessageRead(String messageId) {
    return _remoteDatasource.markMessageRead(messageId);
  }

  @override
  Future<void> sendMessage(MessageEntity message) {
    final model = MessageModel(
      id: message.id,
      conversationId: message.conversationId,
      senderId: message.senderId,
      body: message.body,
      type: message.type,
      sentAt: message.sentAt,
      isRead: message.isRead,
    );
    return _remoteDatasource.sendMessage(model);
  }
}
