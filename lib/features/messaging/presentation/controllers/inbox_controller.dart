import 'package:flutter/foundation.dart';

import '../../domain/entities/conversation_entity.dart';
import '../../domain/usecases/get_conversations_usecase.dart';

class InboxController extends ChangeNotifier {
  InboxController({this.getConversationsUsecase});

  final GetConversationsUsecase? getConversationsUsecase;

  List<ConversationEntity> _conversations = const <ConversationEntity>[];

  List<ConversationEntity> get conversations => _conversations;

  Future<void> load() async {
    _conversations =
        await getConversationsUsecase?.call() ?? const <ConversationEntity>[];
    notifyListeners();
  }
}
