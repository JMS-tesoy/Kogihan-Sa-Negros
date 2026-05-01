import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/services/messaging_service.dart';
import '../widgets/inbox_conversation_helpers.dart';
import '../widgets/message_palettes.dart';
import 'chat_page.dart';
import '../../../../app/router/instant_route.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<MessagesTab> {
  bool _isLoading = true;
  String? _errorText;
  List<ConversationSummary> _conversations = const [];
  final Map<String, double> _dismissProgressByConversationId =
      <String, double>{};
  Timer? _inboxClockRefreshTimer;

  @override
  void initState() {
    super.initState();
    final List<ConversationSummary> cachedConversations =
        MessagingService.getCachedConversationSummaries();
    if (cachedConversations.isNotEmpty) {
      _conversations = cachedConversations;
      _isLoading = false;
    }
    _scheduleInboxClockRefresh();
    unawaited(_loadConversations(showLoader: cachedConversations.isEmpty));
  }

  @override
  void dispose() {
    _inboxClockRefreshTimer?.cancel();
    super.dispose();
  }

  void _scheduleInboxClockRefresh() {
    _inboxClockRefreshTimer?.cancel();

    final DateTime now = DateTime.now();
    final Duration delay =
        Duration(minutes: 1) -
        Duration(
          seconds: now.second,
          milliseconds: now.millisecond,
          microseconds: now.microsecond,
        );

    _inboxClockRefreshTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleInboxClockRefresh();
    });
  }

  InboxCardPalette _paletteForConversation(
    BuildContext context,
    ConversationSummary conversation,
  ) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InboxCardPalette(
      background: colorScheme.surface,
      border: colorScheme.outlineVariant,
      accent: colorScheme.primary,
      avatarBackground: colorScheme.surfaceContainerHighest,
      avatarForeground: colorScheme.onSurface,
    );
  }

  void _setConversationDismissProgress(String conversationId, double progress) {
    final double clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final double currentProgress =
        _dismissProgressByConversationId[conversationId] ?? 0;
    if (clampedProgress <= 0) {
      if (!_dismissProgressByConversationId.containsKey(conversationId)) return;
      setState(() {
        _dismissProgressByConversationId.remove(conversationId);
      });
      return;
    }

    if ((currentProgress - clampedProgress).abs() < 0.02) return;
    setState(() {
      _dismissProgressByConversationId[conversationId] = clampedProgress;
    });
  }

  Future<void> _loadConversations({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      final List<ConversationSummary> conversations =
          await MessagingService.fetchMyConversationSummaries();

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
        _errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = 'Failed to load inbox.';
      });
    }
  }

  Future<void> _openConversation(ConversationSummary conversation) async {
    final int index = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index != -1 && _conversations[index].isUnread) {
      setState(() {
        _conversations[index] = _conversations[index].copyWith(isUnread: false);
      });
      unawaited(MessagingService.markConversationAsRead(conversation.id));
    }

    await Navigator.push(
      context,
      instantRoute(
        ChatPage(
          conversationId: conversation.id,
          senderName: conversation.otherParticipantName,
          initialMessages: MessagingService.getCachedConversationMessages(
            conversation.id,
            limit: MessagingService.initialMessagePageSize,
          ),
        ),
      ),
    );

    await _loadConversations(showLoader: false);
  }

  Future<bool> _confirmDeleteConversation(
    ConversationSummary conversation,
  ) async {
    final String displayTitle = buyerInboxConversationTitle(conversation);
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete conversation'),
          content: Text(
            'Delete your conversation for "$displayTitle"? This will also remove its messages.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return mounted && shouldDelete == true;
  }

  Future<void> _deleteConversation(ConversationSummary conversation) async {
    try {
      await MessagingService.deleteConversation(conversation.id);
      if (!mounted) return;

      setState(() {
        _conversations = _conversations
            .where((item) => item.id != conversation.id)
            .toList();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Conversation deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete conversation: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inbox',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadConversations(showLoader: false),
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_errorText != null) {
                      return ListView(
                        children: [
                          const SizedBox(height: 120),
                          Center(
                            child: Text(
                              _errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (_conversations.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('No messages yet.')),
                        ],
                      );
                    }

                    return ListView.separated(
                      itemCount: _conversations.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ConversationSummary conversation =
                            _conversations[index];
                        return _buildMessageTile(context, conversation);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTile(
    BuildContext context,
    ConversationSummary conversation,
  ) {
    final String displayTitle = buyerInboxConversationTitle(conversation);
    final InboxCardPalette palette = _paletteForConversation(
      context,
      conversation,
    );
    final ImageProvider<Object>? propertyImageProvider =
        buyerInboxConversationImageProvider(context, conversation);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      onUpdate: (details) {
        _setConversationDismissProgress(conversation.id, details.progress);
      },
      confirmDismiss: (_) async {
        final bool shouldDelete = await _confirmDeleteConversation(
          conversation,
        );
        if (!shouldDelete && mounted) {
          _setConversationDismissProgress(conversation.id, 0);
        }
        return shouldDelete;
      },
      onDismissed: (_) {
        _dismissProgressByConversationId.remove(conversation.id);
        _deleteConversation(conversation);
      },
      background: const SizedBox.shrink(),
      secondaryBackground: _buildDeleteSwipeBackground(
        context,
        conversation.id,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: palette.background,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: palette.border),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _openConversation(conversation),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double thumbnailWidth = (constraints.maxWidth * 0.28)
                      .clamp(88.0, 112.0)
                      .toDouble();

                  return SizedBox(
                    height: 88,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: thumbnailWidth,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: palette.avatarBackground,
                            ),
                            child: propertyImageProvider != null
                                ? Image(
                                    image: propertyImageProvider,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      messageInitial(displayTitle),
                                      style: TextStyle(
                                        color: palette.avatarForeground,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayTitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          height: 1.15,
                                          fontWeight: conversation.isUnread
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (conversation.isUnread) ...[
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: palette.accent,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                          ],
                                          Text(
                                            formatInboxTimestamp(
                                              conversation.lastMessageAt,
                                            ),
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: conversation.isUnread
                                                  ? palette.accent
                                                  : colorScheme
                                                        .onSurfaceVariant,
                                              fontWeight: conversation.isUnread
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'Chat Agent',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteSwipeBackground(
    BuildContext context,
    String conversationId,
  ) {
    const Color lightOrange = Color(0xFFFFE0B2);
    const Color warmOrange = Color(0xFFFFB74D);
    const Color iconForeground = Color(0xFF7A3E00);
    final double progress =
        (_dismissProgressByConversationId[conversationId] ?? 0)
            .clamp(0.0, 1.0)
            .toDouble();
    final double opacity = Curves.easeOutCubic.transform(progress);
    final double scaleProgress = Curves.easeOutBack
        .transform(progress)
        .clamp(0.0, 1.12)
        .toDouble();
    final double iconScale = 0.7 + (0.3 * scaleProgress);
    final double iconRotation = -0.28 + (0.28 * opacity);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              warmOrange.withValues(alpha: 0.7),
              lightOrange.withValues(alpha: 0.36),
              lightOrange.withValues(alpha: 0),
            ],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(16 * (1 - progress), 0),
              child: Transform.scale(
                scale: iconScale,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Transform.rotate(
                    angle: iconRotation,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: iconForeground,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
