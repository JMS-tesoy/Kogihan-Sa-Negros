import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/services/messaging_service.dart';
import '../widgets/chat_loading_placeholder.dart';
import '../widgets/message_palettes.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String senderName;
  final List<ConversationMessage> initialMessages;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.senderName,
    this.initialMessages = const [],
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  bool _isLoading = true;
  bool _isSending = false;
  bool _isAttaching = false;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  String? _errorText;
  List<ConversationMessage> _messages = const [];
  RealtimeChannel? _messagesChannel;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  ChatColorPalette _chatPalette(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return ChatColorPalette(
      scaffoldBackground: theme.scaffoldBackgroundColor,
      appBarBackground:
          theme.appBarTheme.backgroundColor ?? colorScheme.surface,
      appBarForeground:
          theme.appBarTheme.foregroundColor ?? colorScheme.onSurface,
      avatarBackground: colorScheme.primaryContainer,
      avatarForeground: colorScheme.onPrimaryContainer,
      outgoingBubble: colorScheme.primaryContainer,
      outgoingText: colorScheme.onPrimaryContainer,
      incomingBubble: colorScheme.surfaceContainerHighest,
      incomingText: colorScheme.onSurface,
      composerFill: theme.cardColor,
      sendButtonBackground: colorScheme.primary,
      sendButtonForeground: colorScheme.onPrimary,
    );
  }

  @override
  void initState() {
    super.initState();
    _messages = List<ConversationMessage>.from(widget.initialMessages);
    _isLoading = _messages.isEmpty;
    _hasMoreMessages =
        _messages.length >= MessagingService.initialMessagePageSize;
    _messagesScrollController.addListener(_handleMessagesScroll);
    _subscribeToMessageUpdates();
    if (_messages.isNotEmpty) {
      _jumpToBottom();
    }
    unawaited(MessagingService.markConversationAsRead(widget.conversationId));
    unawaited(
      _loadMessages(showLoader: _messages.isEmpty, scrollToBottom: true),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messagesScrollController.dispose();
    if (_messagesChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_messagesChannel!));
    }
    super.dispose();
  }

  void _subscribeToMessageUpdates() {
    _messagesChannel = Supabase.instance.client
        .channel('buyer-chat-${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (_) {
            if (!mounted) return;
            unawaited(
              MessagingService.markConversationAsRead(widget.conversationId),
            );
            unawaited(_loadMessages(showLoader: false, scrollToBottom: true));
          },
        )
        .subscribe();
  }

  void _handleMessagesScroll() {
    if (!_messagesScrollController.hasClients ||
        _isLoadingMore ||
        !_hasMoreMessages ||
        _messages.isEmpty) {
      return;
    }

    if (_messagesScrollController.position.pixels <= 120) {
      unawaited(_loadOlderMessages());
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) return;
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) return;
      _messagesScrollController.jumpTo(
        _messagesScrollController.position.maxScrollExtent,
      );
    });
  }

  List<ConversationMessage> _mergeMessages(
    Iterable<ConversationMessage> existing,
    Iterable<ConversationMessage> incoming,
  ) {
    final Map<String, ConversationMessage> byId =
        <String, ConversationMessage>{};
    for (final ConversationMessage message in existing) {
      byId[message.id] = message;
    }
    for (final ConversationMessage message in incoming) {
      byId[message.id] = message;
    }

    final List<ConversationMessage> merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  Future<void> _loadMessages({
    bool showLoader = true,
    bool scrollToBottom = false,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      final List<ConversationMessage> messages =
          await MessagingService.fetchConversationMessages(
            widget.conversationId,
            limit: MessagingService.initialMessagePageSize,
          );
      final int previousCount = _messages.length;
      final List<ConversationMessage> mergedMessages = _mergeMessages(
        _messages,
        messages,
      );

      if (!mounted) return;
      setState(() {
        _messages = mergedMessages;
        _isLoading = false;
        _errorText = null;
        _isSending = false;
        _hasMoreMessages =
            messages.length >= MessagingService.initialMessagePageSize;
      });
      if (scrollToBottom || mergedMessages.length > previousCount) {
        if (previousCount == 0) {
          _jumpToBottom();
        } else {
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSending = false;
        _errorText = 'Failed to load messages.';
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;

    final DateTime before = _messages.first.createdAt;
    final double previousOffset = _messagesScrollController.hasClients
        ? _messagesScrollController.offset
        : 0;
    final double previousMaxExtent = _messagesScrollController.hasClients
        ? _messagesScrollController.position.maxScrollExtent
        : 0;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final List<ConversationMessage> olderMessages =
          await MessagingService.fetchConversationMessages(
            widget.conversationId,
            limit: MessagingService.initialMessagePageSize,
            before: before,
          );
      final List<ConversationMessage> mergedMessages = _mergeMessages(
        _messages,
        olderMessages,
      );

      if (!mounted) return;
      setState(() {
        _messages = mergedMessages;
        _isLoadingMore = false;
        _hasMoreMessages =
            olderMessages.length >= MessagingService.initialMessagePageSize;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_messagesScrollController.hasClients) return;
        final double delta =
            _messagesScrollController.position.maxScrollExtent -
            previousMaxExtent;
        _messagesScrollController.jumpTo(previousOffset + delta);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _sendMessage({ChatAttachment? attachment}) async {
    final String text = _messageController.text.trim();
    if ((text.isEmpty && attachment == null) || _isSending) return;

    final String optimisticBody = text.isNotEmpty
        ? text
        : attachment != null
        ? 'Sent an attachment'
        : '';

    final ConversationMessage optimisticMessage = ConversationMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      body: optimisticBody,
      createdAt: DateTime.now(),
      readAt: null,
      attachmentUrl: attachment?.url,
      attachmentPath: attachment?.path,
      attachmentName: attachment?.name,
      attachmentMimeType: attachment?.mimeType,
      attachmentSizeBytes: attachment?.sizeBytes,
    );

    setState(() {
      _isSending = true;
      _errorText = null;
      _messages = [..._messages, optimisticMessage];
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final ConversationMessage sentMessage =
          await MessagingService.sendMessage(
            conversationId: widget.conversationId,
            body: text,
            attachment: attachment,
          );
      if (!mounted) return;
      final List<ConversationMessage> currentMessages = _messages
          .where((message) => message.id != optimisticMessage.id)
          .toList();
      setState(() {
        _isSending = false;
        _messages = _mergeMessages(currentMessages, [sentMessage]);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorText = 'Failed to send message.';
        _messages = _messages
            .where((message) => message.id != optimisticMessage.id)
            .toList();
        _messageController.text = text;
      });
      AppSnackBar.error(context, 'Failed to send message: $e');
    }
  }

  Future<void> _pickAndSendAttachment() async {
    if (_isSending || _isAttaching) return;

    setState(() {
      _isAttaching = true;
      _errorText = null;
    });

    try {
      final ChatAttachment? attachment =
          await MessagingService.pickAndUploadAttachment(folder: 'buyer-agent');
      if (!mounted || attachment == null) return;
      await _sendMessage(attachment: attachment);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to attach file: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAttaching = false;
        });
      }
    }
  }

  Future<void> _openAttachment(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      AppSnackBar.warning(context, 'Unable to open attachment.');
    }
  }

  Future<void> _showMessageActions(ConversationMessage message) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      await _editMessage(message);
    } else if (action == 'delete') {
      await _deleteMessage(message);
    }
  }

  Future<void> _editMessage(ConversationMessage message) async {
    final TextEditingController controller = TextEditingController(
      text: message.body,
    );

    final String? updatedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Update your message'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || updatedText == null || updatedText.isEmpty) return;
    if (updatedText == message.body.trim()) return;

    try {
      await MessagingService.updateMessage(
        messageId: message.id,
        body: updatedText,
      );
      await _loadMessages(showLoader: false, scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to edit message: $e');
    }
  }

  Future<void> _deleteMessage(ConversationMessage message) async {
    final bool shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete message'),
              content: const Text(
                'This message will be removed from the chat.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted || !shouldDelete) return;

    try {
      await MessagingService.deleteMessage(message.id);
      await _loadMessages(showLoader: false, scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to delete message: $e');
    }
  }

  bool _shouldShowMessageBody(ConversationMessage message) {
    final String body = message.body.trim();
    if (body.isEmpty) return false;
    return !(message.hasAttachment && body == 'Sent an attachment');
  }

  Widget _buildAttachmentPreview({
    required ConversationMessage message,
    required Color textColor,
  }) {
    final String attachmentUrl = message.attachmentUrl ?? '';
    final String attachmentName = message.attachmentDisplayName;

    if (message.attachmentIsImage) {
      return InkWell(
        onTap: () => _openAttachment(attachmentUrl),
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            attachmentUrl,
            width: 220,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildFileAttachmentCard(
                attachmentName: attachmentName,
                textColor: textColor,
              );
            },
          ),
        ),
      );
    }

    return _buildFileAttachmentCard(
      attachmentName: attachmentName,
      textColor: textColor,
      onTap: () => _openAttachment(attachmentUrl),
    );
  }

  Widget _buildFileAttachmentCard({
    required String attachmentName,
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: textColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: textColor.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded, color: textColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                attachmentName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatColorPalette palette = _chatPalette(context);

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: palette.appBarBackground,
        foregroundColor: palette.appBarForeground,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: palette.avatarBackground,
              foregroundColor: palette.avatarForeground,
              child: Text(
                widget.senderName[0],
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Text(widget.senderName, style: const TextStyle(fontSize: 18)),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading && _messages.isEmpty) {
                  return const ChatLoadingPlaceholder();
                }

                if (_errorText != null && _messages.isEmpty) {
                  return Center(
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }

                if (_messages.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('No messages yet.')),
                    ],
                  );
                }

                return ListView.builder(
                  controller: _messagesScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isLoadingMore && index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final int messageIndex = _isLoadingMore ? index - 1 : index;
                    final ConversationMessage msg = _messages[messageIndex];
                    final bool isMe = msg.isFrom(_currentUserId);
                    final Color bubbleColor = isMe
                        ? palette.outgoingBubble
                        : palette.incomingBubble;
                    final Color textColor = isMe
                        ? palette.outgoingText
                        : palette.incomingText;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMe && !msg.isPending
                            ? () => _showMessageActions(msg)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMe
                                  ? const Radius.circular(0)
                                  : const Radius.circular(16),
                              bottomLeft: !isMe
                                  ? const Radius.circular(0)
                                  : const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (msg.hasAttachment) ...[
                                _buildAttachmentPreview(
                                  message: msg,
                                  textColor: textColor,
                                ),
                                if (_shouldShowMessageBody(msg))
                                  const SizedBox(height: 8),
                              ],
                              if (_shouldShowMessageBody(msg))
                                Text(
                                  msg.body,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 16,
                                  ),
                                ),
                              if (isMe) ...[
                                const SizedBox(height: 6),
                                Text(
                                  msg.isPending ? 'Sending...' : 'Sent',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textColor.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_errorText != null && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 23,
                    backgroundColor: palette.composerFill,
                    child: IconButton(
                      tooltip: 'Attach file',
                      onPressed: _isSending || _isAttaching
                          ? null
                          : _pickAndSendAttachment,
                      icon: Icon(
                        Icons.attach_file_rounded,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: palette.composerFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: palette.sendButtonBackground,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _isSending || _isAttaching
                          ? SizedBox(
                              key: const ValueKey('sending'),
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  palette.sendButtonForeground,
                                ),
                              ),
                            )
                          : IconButton(
                              key: const ValueKey('send'),
                              icon: Icon(
                                Icons.send_rounded,
                                color: palette.sendButtonForeground,
                              ),
                              onPressed: _isSending || _isAttaching
                                  ? null
                                  : () => _sendMessage(),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
