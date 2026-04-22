import 'package:flutter/material.dart';

import '../../domain/entities/conversation_entity.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    this.onTap,
  });

  final ConversationEntity conversation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(conversation.title),
      subtitle: Text(conversation.lastMessage),
      onTap: onTap,
    );
  }
}
