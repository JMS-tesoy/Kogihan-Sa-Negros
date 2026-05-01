import 'package:flutter/foundation.dart';

import '../../domain/entities/message_entity.dart';
import '../../domain/usecases/get_messages_usecase.dart';

class ChatController extends ChangeNotifier {
  ChatController({this.getMessagesUsecase});

  final GetMessagesUsecase? getMessagesUsecase;

  List<MessageEntity> _messages = const <MessageEntity>[];

  List<MessageEntity> get messages => _messages;

  Future<void> load(String conversationId) async {
    _messages =
        await getMessagesUsecase?.call(conversationId) ??
        const <MessageEntity>[];
    notifyListeners();
  }
}
