import 'package:flutter/material.dart';

import '../../data/services/messaging_service.dart';
import 'chat_page.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.senderName,
    this.initialMessages = const <ConversationMessage>[],
  });

  final String conversationId;
  final String senderName;
  final List<ConversationMessage> initialMessages;

  @override
  Widget build(BuildContext context) {
    return ChatPage(
      conversationId: conversationId,
      senderName: senderName,
      initialMessages: initialMessages,
    );
  }
}

class ChatScreenArgs {
  const ChatScreenArgs({
    required this.conversationId,
    required this.senderName,
    this.initialMessages = const <ConversationMessage>[],
  });

  final String conversationId;
  final String senderName;
  final List<ConversationMessage> initialMessages;
}
