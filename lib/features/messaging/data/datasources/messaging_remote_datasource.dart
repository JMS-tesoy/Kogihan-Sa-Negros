import '../models/conversation_model.dart';
import '../models/message_model.dart';

class MessagingRemoteDatasource {
  Future<List<ConversationModel>> getConversations() async {
    return const <ConversationModel>[];
  }

  Future<List<MessageModel>> getMessages(String conversationId) async {
    return const <MessageModel>[];
  }

  Future<void> sendMessage(MessageModel message) async {}

  Future<void> markMessageRead(String messageId) async {}
}
