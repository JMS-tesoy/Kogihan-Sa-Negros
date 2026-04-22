import 'package:flutter/material.dart';

class InboxCardPalette {
  final Color background;
  final Color border;
  final Color accent;
  final Color avatarBackground;
  final Color avatarForeground;

  const InboxCardPalette({
    required this.background,
    required this.border,
    required this.accent,
    required this.avatarBackground,
    required this.avatarForeground,
  });
}

class ChatColorPalette {
  final Color scaffoldBackground;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color avatarBackground;
  final Color avatarForeground;
  final Color outgoingBubble;
  final Color outgoingText;
  final Color incomingBubble;
  final Color incomingText;
  final Color composerFill;
  final Color sendButtonBackground;
  final Color sendButtonForeground;

  const ChatColorPalette({
    required this.scaffoldBackground,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.avatarBackground,
    required this.avatarForeground,
    required this.outgoingBubble,
    required this.outgoingText,
    required this.incomingBubble,
    required this.incomingText,
    required this.composerFill,
    required this.sendButtonBackground,
    required this.sendButtonForeground,
  });
}
