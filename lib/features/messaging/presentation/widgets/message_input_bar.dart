import 'package:flutter/material.dart';

class MessageInputBar extends StatelessWidget {
  const MessageInputBar({super.key, this.onSend});

  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController();
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Message'),
          ),
        ),
        IconButton(
          tooltip: 'Send',
          onPressed: () => onSend?.call(controller.text),
          icon: const Icon(Icons.send),
        ),
      ],
    );
  }
}
