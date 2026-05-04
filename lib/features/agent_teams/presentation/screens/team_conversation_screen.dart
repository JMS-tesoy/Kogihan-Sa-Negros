import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../../messaging/data/services/messaging_service.dart';
import '../../data/services/team_messages_service.dart';
import '../../data/models/team_chat_message.dart';
import '../../data/models/team_chat_team.dart';

String _formatTeamInboxTime(DateTime? value) {
  if (value == null) return '';

  final DateTime localValue = value.toLocal();
  final DateTime now = DateTime.now();
  final Duration difference = now.difference(localValue);

  if (difference.inDays == 0) {
    final int hour = localValue.hour % 12 == 0 ? 12 : localValue.hour % 12;
    final String minute = localValue.minute.toString().padLeft(2, '0');
    final String suffix = localValue.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  if (difference.inDays == 1) return 'Yesterday';

  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[localValue.month - 1]} ${localValue.day}';
}

class TeamConversationPage extends StatefulWidget {
  const TeamConversationPage({super.key, required this.team});

  final TeamChatTeam team;

  @override
  State<TeamConversationPage> createState() => _TeamConversationPageState();
}

class _TeamConversationPageState extends State<TeamConversationPage> {
  static const int _messageLimit = 80;

  final TeamMessagesService _teamMessagesService = TeamMessagesService();
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  RealtimeChannel? _teamMessagesChannel;
  List<TeamChatMessage> _messages = const <TeamChatMessage>[];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isAttaching = false;
  String? _error;

  String get _currentUserId => _teamMessagesService.currentUserId;

  String get _currentUserDisplayName =>
      _teamMessagesService.currentUserDisplayName;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
    _subscribeToTeamMessages();
    unawaited(_loadMessages(scrollToBottom: true));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    if (_teamMessagesChannel != null) {
      unawaited(_teamMessagesService.removeChannel(_teamMessagesChannel!));
    }
    super.dispose();
  }

  void _subscribeToTeamMessages() {
    _teamMessagesChannel = _teamMessagesService.subscribeToTeamMessages(
      teamId: widget.team.id,
      onChanged: () {
        if (!mounted) return;
        unawaited(_loadMessages(scrollToBottom: true, showLoader: false));
      },
    );
  }

  Future<void> _loadMessages({
    bool scrollToBottom = false,
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final List<TeamChatMessage> messages = await _teamMessagesService
          .fetchMessages(teamId: widget.team.id, limit: _messageLimit);

      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoading = false;
        _error = null;
      });

      if (scrollToBottom) _scrollToBottom(jump: messages.length <= 1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Failed to load team messages. $e';
      });
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final double target = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(target);
        return;
      }
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _sendMessage({ChatAttachment? attachment}) async {
    final String body = _messageController.text.trim();

    if (_isSending || _currentUserId.isEmpty) {
      return;
    }

    if (body.isEmpty && attachment == null) {
      AppSnackBar.warning(context, 'Message cannot be empty.');
      return;
    }

    if (body.length > 1000) {
      AppSnackBar.warning(
        context,
        'Message is too long. Maximum is 1000 characters.',
      );
      return;
    }

    final String bodyToSend = body.isNotEmpty
        ? body
        : attachment != null
        ? 'Sent an attachment'
        : '';

    final TeamChatMessage optimisticMessage = TeamChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      teamId: widget.team.id,
      senderId: _currentUserId,
      senderName: _currentUserDisplayName,
      body: bodyToSend,
      createdAt: DateTime.now(),
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
    _messageController.clear();
    _scrollToBottom();

    try {
      final TeamChatMessage sentMessage = await _teamMessagesService
          .sendMessage(
            teamId: widget.team.id,
            body: bodyToSend,
            attachment: attachment,
          );
      if (!mounted) return;
      setState(() {
        _messages = _messages
            .where((message) => message.id != optimisticMessage.id)
            .toList();
        _messages = [..._messages, sentMessage]
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      _messageController.text = body;
      setState(() {
        _messages = _messages
            .where((message) => message.id != optimisticMessage.id)
            .toList();
      });
      AppSnackBar.error(context, 'Failed to send team message: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAndSendAttachment() async {
    if (_isSending || _isAttaching) return;

    setState(() {
      _isAttaching = true;
    });

    try {
      final ChatAttachment? attachment =
          await MessagingService.pickAndUploadAttachment(folder: 'team-inbox');
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.team.name)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: theme.brightness == Brightness.light ? 0.55 : 0.32,
            ),
            child: Text(
              'Team Inbox · realtime internal chat',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: _buildMessagesArea(context)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Attach file',
                    onPressed: _isSending || _isAttaching
                        ? null
                        : _pickAndSendAttachment,
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.team.name}',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _isSending || _isAttaching
                        ? null
                        : () => _sendMessage(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: _isSending || _isAttaching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _loadMessages(scrollToBottom: true),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 80),
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _loadMessages(scrollToBottom: true),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 100),
            Icon(
              Icons.forum_outlined,
              size: 44,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No team messages yet.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Send the first internal team update here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadMessages(scrollToBottom: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final TeamChatMessage message = _messages[index];
          return _buildMessageBubble(context, message);
        },
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, TeamChatMessage message) {
    final ThemeData theme = Theme.of(context);
    final bool isMine = message.senderId == _currentUserId;
    final Alignment alignment = isMine
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final Color bubbleColor = isMine
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;
    final Color foregroundColor = isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    final String timeLabel = _formatTeamInboxTime(message.createdAt);

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMine) ...[
              Text(
                message.senderName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: foregroundColor.withValues(alpha: 0.72),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
            ],
            if (message.hasAttachment) ...[
              _buildTeamAttachmentPreview(
                context: context,
                message: message,
                foregroundColor: foregroundColor,
              ),
              if (_shouldShowTeamMessageBody(message))
                const SizedBox(height: 8),
            ],
            if (_shouldShowTeamMessageBody(message))
              Text(
                message.body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foregroundColor.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowTeamMessageBody(TeamChatMessage message) {
    final String body = message.body.trim();
    if (body.isEmpty) return false;
    return !(message.hasAttachment && body == 'Sent an attachment');
  }

  Widget _buildTeamAttachmentPreview({
    required BuildContext context,
    required TeamChatMessage message,
    required Color foregroundColor,
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
              return _buildTeamFileAttachmentCard(
                attachmentName: attachmentName,
                foregroundColor: foregroundColor,
              );
            },
          ),
        ),
      );
    }

    return _buildTeamFileAttachmentCard(
      attachmentName: attachmentName,
      foregroundColor: foregroundColor,
      onTap: () => _openAttachment(attachmentUrl),
    );
  }

  Widget _buildTeamFileAttachmentCard({
    required String attachmentName,
    required Color foregroundColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: foregroundColor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: foregroundColor.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file_rounded, color: foregroundColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                attachmentName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
