import '../models/message_model.dart';

class MessagingLocalDatasource {
  final List<MessageModel> _messages = <MessageModel>[];

  Future<void> cacheMessage(MessageModel message) async {
    _messages.add(message);
  }

  Future<List<MessageModel>> getCachedMessages(String conversationId) async {
    return _messages
        .where((message) => message.conversationId == conversationId)
        .toList();
  }
}
