import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../../messaging/data/services/messaging_service.dart';
import '../models/agent_inquiry.dart';

Route<T> _instantRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => child,
  );
}

class AgentInboxPage extends StatefulWidget {
  final List<AgentInquiry> inquiries;
  final ValueChanged<String> onMarkAsRead;
  final AgentInboxFilter initialFilter;

  const AgentInboxPage({
    super.key,
    required this.inquiries,
    required this.onMarkAsRead,
    this.initialFilter = AgentInboxFilter.all,
  });

  @override
  State<AgentInboxPage> createState() => _AgentInboxPageState();
}

class _AgentInboxPageState extends State<AgentInboxPage> {
  late List<AgentInquiry> _inquiries;
  late AgentInboxFilter _activeFilter;
  RealtimeChannel? _inboxChannel;

  List<AgentInquiry> get _visibleInquiries {
    if (_activeFilter == AgentInboxFilter.unread) {
      return _inquiries
          .where((inquiry) => inquiry.isUnread)
          .toList(growable: false);
    }

    return _inquiries;
  }

  String get _pageTitle {
    return _activeFilter == AgentInboxFilter.unread
        ? 'Unread Inquiries'
        : 'Buyer Messages';
  }

  String get _emptyMessage {
    return _activeFilter == AgentInboxFilter.unread
        ? 'No unread buyer inquiries.'
        : 'No buyer inquiries yet.';
  }

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.initialFilter;
    _inquiries = widget.inquiries.isNotEmpty
        ? List<AgentInquiry>.from(widget.inquiries)
        : cachedAgentInquiries();
    _subscribeToInboxUpdates();
    unawaited(_refreshInquiries());
  }

  @override
  void dispose() {
    if (_inboxChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_inboxChannel!));
    }
    super.dispose();
  }

  void _subscribeToInboxUpdates() {
    final SupabaseClient client = Supabase.instance.client;
    _inboxChannel = client
        .channel('agent-inbox-page')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (!mounted) return;
            unawaited(_refreshInquiries());
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) {
            if (!mounted) return;
            unawaited(_refreshInquiries());
          },
        )
        .subscribe();
  }

  Future<void> _refreshInquiries() async {
    try {
      final List<ConversationSummary> summaries =
          await MessagingService.fetchMyConversationSummaries();
      if (!mounted) return;
      setState(() {
        _inquiries = AgentInquiry.groupedFromConversationSummaries(summaries);
      });
    } catch (_) {}
  }

  Future<void> _openInquiry(AgentInquiry inquiry) async {
    if (inquiry.isUnread) {
      final int index = _inquiries.indexWhere((item) => item.id == inquiry.id);
      if (index != -1) {
        setState(() {
          _inquiries[index] = _inquiries[index].copyWith(isUnread: false);
        });
        widget.onMarkAsRead(inquiry.id);
      }

      unawaited(
        MessagingService.markConversationsAsRead(inquiry.conversationIds),
      );
    }

    await Navigator.push(
      context,
      _instantRoute(InquiryDetailsPage(inquiry: inquiry)),
    );

    await _refreshInquiries();
  }

  @override
  Widget build(BuildContext context) {
    final List<AgentInquiry> visibleInquiries = _visibleInquiries;

    return Scaffold(
      appBar: AppBar(title: Text(_pageTitle)),
      body: RefreshIndicator(
        onRefresh: _refreshInquiries,
        child: visibleInquiries.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(_emptyMessage)),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: visibleInquiries.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final AgentInquiry inquiry = visibleInquiries[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(inquiry.buyerName[0])),
                      title: Text(
                        inquiry.buyerName,
                        style: TextStyle(
                          fontWeight: inquiry.isUnread
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        inquiry.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(inquiry.timeLabel),
                          if (inquiry.isUnread) ...[
                            const SizedBox(height: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                      onTap: () => _openInquiry(inquiry),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class InquiryDetailsPage extends StatefulWidget {
  final AgentInquiry inquiry;

  const InquiryDetailsPage({super.key, required this.inquiry});

  @override
  State<InquiryDetailsPage> createState() => _InquiryDetailsPageState();
}

class _InquiryDetailsPageState extends State<InquiryDetailsPage> {
  late final TextEditingController _replyController;
  late final ScrollController _messagesScrollController;
  bool _isSending = false;
  bool _isAttaching = false;
  bool _isLoadingMessages = true;
  bool _isLoadingMoreMessages = false;
  bool _hasMoreMessages = true;
  List<ConversationMessage> _messages = const [];
  RealtimeChannel? _messagesChannel;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
    _messagesScrollController = ScrollController();
    _messages = MessagingService.getCachedConversationMessagesForConversations(
      widget.inquiry.conversationIds,
      limit: MessagingService.initialMessagePageSize,
    );
    _isLoadingMessages = _messages.isEmpty;
    _hasMoreMessages =
        _messages.length >= MessagingService.initialMessagePageSize;
    _messagesScrollController.addListener(_handleMessagesScroll);
    _subscribeToMessageUpdates();
    if (_messages.isNotEmpty) {
      _jumpToBottom();
    }
    unawaited(
      _loadMessages(scrollToBottom: true, showLoader: _messages.isEmpty),
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    _messagesScrollController.dispose();
    if (_messagesChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_messagesChannel!));
    }
    super.dispose();
  }

  void _subscribeToMessageUpdates() {
    RealtimeChannel channel = Supabase.instance.client.channel(
      'agent-thread-${widget.inquiry.buyerId}',
    );

    for (final String conversationId in widget.inquiry.conversationIds) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'conversation_id',
          value: conversationId,
        ),
        callback: (_) {
          if (!mounted) return;
          unawaited(_loadMessages(scrollToBottom: true, showLoader: false));
        },
      );
    }

    _messagesChannel = channel.subscribe();
  }

  void _handleMessagesScroll() {
    if (!_messagesScrollController.hasClients ||
        _isLoadingMoreMessages ||
        !_hasMoreMessages ||
        _messages.isEmpty) {
      return;
    }

    if (_messagesScrollController.position.pixels <= 120) {
      unawaited(_loadOlderMessages());
    }
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
    bool scrollToBottom = false,
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoadingMessages = true;
      });
    }

    try {
      final List<ConversationMessage> messages =
          await MessagingService.fetchConversationMessagesForConversations(
            widget.inquiry.conversationIds,
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
        _isLoadingMessages = false;
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMessages = false;
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMoreMessages || !_hasMoreMessages || _messages.isEmpty) {
      return;
    }

    final DateTime before = _messages.first.createdAt;
    final double previousOffset = _messagesScrollController.hasClients
        ? _messagesScrollController.offset
        : 0;
    final double previousMaxExtent = _messagesScrollController.hasClients
        ? _messagesScrollController.position.maxScrollExtent
        : 0;

    setState(() {
      _isLoadingMoreMessages = true;
    });

    try {
      final List<ConversationMessage> olderMessages =
          await MessagingService.fetchConversationMessagesForConversations(
            widget.inquiry.conversationIds,
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
        _isLoadingMoreMessages = false;
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
        _isLoadingMoreMessages = false;
      });
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

  Future<void> _sendReply({ChatAttachment? attachment}) async {
    final String replyText = _replyController.text.trim();
    if ((replyText.isEmpty && attachment == null) || _isSending) return;

    final String optimisticBody = replyText.isNotEmpty
        ? replyText
        : attachment != null
        ? 'Sent an attachment'
        : '';

    final ConversationMessage optimisticMessage = ConversationMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: widget.inquiry.primaryConversationId,
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
      _messages = [..._messages, optimisticMessage];
    });
    _replyController.clear();
    _scrollToBottom();

    try {
      final ConversationMessage sentMessage =
          await MessagingService.sendMessage(
            conversationId: widget.inquiry.primaryConversationId,
            body: replyText,
            attachment: attachment,
          );

      if (!mounted) return;
      final List<ConversationMessage> currentMessages = _messages
          .where((message) => message.id != optimisticMessage.id)
          .toList();
      setState(() {
        _messages = _mergeMessages(currentMessages, [sentMessage]);
      });
    } catch (e) {
      if (!mounted) return;
      _replyController.text = replyText;
      setState(() {
        _messages = _messages
            .where((message) => message.id != optimisticMessage.id)
            .toList();
      });
      AppSnackBar.error(context, 'Failed to send reply: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendReplyAttachment() async {
    if (_isSending || _isAttaching) return;

    setState(() {
      _isAttaching = true;
    });

    try {
      final ChatAttachment? attachment =
          await MessagingService.pickAndUploadAttachment(folder: 'buyer-agent');
      if (!mounted || attachment == null) return;
      await _sendReply(attachment: attachment);
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

  Future<void> _openConversationAttachment(String url) async {
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
      await _loadMessages(scrollToBottom: true);
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
      await _loadMessages(scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to delete message: $e');
    }
  }

  bool _shouldShowConversationBody(ConversationMessage message) {
    final String body = message.body.trim();
    if (body.isEmpty) return false;
    return !(message.hasAttachment && body == 'Sent an attachment');
  }

  Widget _buildConversationAttachmentPreview({
    required ConversationMessage message,
    required Color textColor,
  }) {
    final String attachmentUrl = message.attachmentUrl ?? '';
    final String attachmentName = message.attachmentDisplayName;

    if (message.attachmentIsImage) {
      return InkWell(
        onTap: () => _openConversationAttachment(attachmentUrl),
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            attachmentUrl,
            width: 220,
            height: 150,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return _buildConversationFileAttachmentCard(
                attachmentName: attachmentName,
                textColor: textColor,
              );
            },
          ),
        ),
      );
    }

    return _buildConversationFileAttachmentCard(
      attachmentName: attachmentName,
      textColor: textColor,
      onTap: () => _openConversationAttachment(attachmentUrl),
    );
  }

  Widget _buildConversationFileAttachmentCard({
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.inquiry.buyerName)),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Messages',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.inquiry.conversationTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _isLoadingMessages
                        ? const _InquiryThreadLoadingPlaceholder()
                        : _messages.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('No messages yet.')),
                            ],
                          )
                        : ListView.separated(
                            controller: _messagesScrollController,
                            itemCount:
                                _messages.length +
                                (_isLoadingMoreMessages ? 1 : 0),
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (_isLoadingMoreMessages && index == 0) {
                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                );
                              }

                              final int messageIndex = _isLoadingMoreMessages
                                  ? index - 1
                                  : index;
                              final ConversationMessage message =
                                  _messages[messageIndex];
                              final ThemeData theme = Theme.of(context);
                              final bool isAgentMessage = message.isFrom(
                                _currentUserId,
                              );
                              final Color bubbleColor = isAgentMessage
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.secondaryContainer;
                              final Color textColor = isAgentMessage
                                  ? theme.colorScheme.onPrimaryContainer
                                  : theme.colorScheme.onSecondaryContainer;
                              final Color metaColor = isAgentMessage
                                  ? textColor.withValues(alpha: 0.75)
                                  : textColor.withValues(alpha: 0.8);

                              return Align(
                                alignment: isAgentMessage
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress:
                                      isAgentMessage && !message.isPending
                                      ? () => _showMessageActions(message)
                                      : null,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 320,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: bubbleColor,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (message.hasAttachment) ...[
                                            _buildConversationAttachmentPreview(
                                              message: message,
                                              textColor: textColor,
                                            ),
                                            if (_shouldShowConversationBody(
                                              message,
                                            ))
                                              const SizedBox(height: 8),
                                          ],
                                          if (_shouldShowConversationBody(
                                            message,
                                          ))
                                            Text(
                                              message.body,
                                              style: TextStyle(
                                                color: textColor,
                                              ),
                                            ),
                                          const SizedBox(height: 8),
                                          Text(
                                            isAgentMessage
                                                ? (message.isPending
                                                      ? 'Sending...'
                                                      : 'Sent')
                                                : formatInboxTime(
                                                    message.createdAt,
                                                  ),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: metaColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Attach file',
                    onPressed: _isSending || _isAttaching
                        ? null
                        : _pickAndSendReplyAttachment,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Type your reply...',
                        filled: true,
                        fillColor: Theme.of(context).cardColor,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendReply(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary,
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
                                  Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            )
                          : IconButton(
                              key: const ValueKey('send'),
                              onPressed: _isSending || _isAttaching
                                  ? null
                                  : () => _sendReply(),
                              icon: Icon(
                                Icons.send_rounded,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
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

class _InquiryThreadLoadingPlaceholder extends StatelessWidget {
  const _InquiryThreadLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final Color baseColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final Color highlightColor = Color.alphaBlend(
      Colors.white.withValues(alpha: 0.35),
      baseColor,
    );

    return ListView(
      children: List<Widget>.generate(6, (index) {
        final bool isAgentBubble = index.isOdd;
        return Align(
          alignment: isAgentBubble
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: isAgentBubble ? 260 : 200,
              height: 72,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      }),
    );
  }
}
