import 'package:flutter/material.dart';

class MessageInputBar extends StatefulWidget {
  const MessageInputBar({
    super.key,
    this.hintText = 'Message',
    this.isSending = false,
    this.onSend,
    this.onAttach,
  });

  final String hintText;
  final bool isSending;
  final ValueChanged<String>? onSend;
  final VoidCallback? onAttach;

  @override
  State<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<MessageInputBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final String text = _controller.text.trim();
    if (text.isEmpty || widget.isSending) return;
    widget.onSend?.call(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton.filledTonal(
          tooltip: 'Attach file',
          onPressed: widget.isSending ? null : widget.onAttach,
          icon: const Icon(Icons.attach_file_rounded),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: widget.hintText,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => _send(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Send',
          onPressed: widget.isSending ? null : _send,
          icon: widget.isSending
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send_rounded),
        ),
      ],
    );
  }
}
