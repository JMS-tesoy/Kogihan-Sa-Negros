import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/message_input_bar.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Chat',
      body: Column(
        children: <Widget>[
          const Expanded(
            child: Center(child: Text('Messages will appear here.')),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: MessageInputBar(onSend: (_) {}),
          ),
        ],
      ),
    );
  }
}
