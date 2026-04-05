import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'messaging_service.dart';
import 'shared_properties.dart';

String _formatInboxTime(DateTime? value) {
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

  const List<String> months = [
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

class AgentInquiry {
  final String id;
  final String buyerId;
  final String buyerName;
  final String message;
  final String timeLabel;
  final bool isUnread;
  final String conversationTitle;
  final String primaryConversationId;
  final List<String> conversationIds;
  final DateTime? lastMessageAt;

  const AgentInquiry({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.message,
    required this.timeLabel,
    required this.isUnread,
    required this.conversationTitle,
    required this.primaryConversationId,
    required this.conversationIds,
    required this.lastMessageAt,
  });

  AgentInquiry copyWith({
    String? id,
    String? buyerId,
    String? buyerName,
    String? message,
    String? timeLabel,
    bool? isUnread,
    String? conversationTitle,
    String? primaryConversationId,
    List<String>? conversationIds,
    DateTime? lastMessageAt,
  }) {
    return AgentInquiry(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      buyerName: buyerName ?? this.buyerName,
      message: message ?? this.message,
      timeLabel: timeLabel ?? this.timeLabel,
      isUnread: isUnread ?? this.isUnread,
      conversationTitle: conversationTitle ?? this.conversationTitle,
      primaryConversationId: primaryConversationId ?? this.primaryConversationId,
      conversationIds: conversationIds ?? this.conversationIds,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }

  factory AgentInquiry.fromConversationSummary(ConversationSummary summary) {
    return AgentInquiry(
      id: summary.otherParticipantId,
      buyerId: summary.otherParticipantId,
      buyerName: summary.otherParticipantName,
      message: summary.lastMessagePreview.isNotEmpty
          ? summary.lastMessagePreview
          : 'No messages yet.',
      timeLabel: _formatInboxTime(summary.lastMessageAt),
      isUnread: summary.isUnread,
      conversationTitle: summary.title,
      primaryConversationId: summary.id,
      conversationIds: [summary.id],
      lastMessageAt: summary.lastMessageAt,
    );
  }

  static List<AgentInquiry> groupedFromConversationSummaries(
    List<ConversationSummary> summaries,
  ) {
    final Map<String, List<ConversationSummary>> grouped = {};

    for (final ConversationSummary summary in summaries) {
      grouped.putIfAbsent(summary.otherParticipantId, () => []).add(summary);
    }

    final List<AgentInquiry> inquiries = grouped.values.map((items) {
      items.sort((a, b) {
        final DateTime? first = a.lastMessageAt;
        final DateTime? second = b.lastMessageAt;
        if (first == null && second == null) return 0;
        if (first == null) return 1;
        if (second == null) return -1;
        return second.compareTo(first);
      });

      final ConversationSummary latest = items.first;
      final List<String> titles = items
          .map((summary) => summary.title.trim())
          .where((title) => title.isNotEmpty)
          .toSet()
          .toList();

      return AgentInquiry(
        id: latest.otherParticipantId,
        buyerId: latest.otherParticipantId,
        buyerName: latest.otherParticipantName,
        message: latest.lastMessagePreview.isNotEmpty
            ? latest.lastMessagePreview
            : 'No messages yet.',
        timeLabel: _formatInboxTime(latest.lastMessageAt),
        isUnread: items.any((summary) => summary.isUnread),
        conversationTitle: titles.length <= 1 ? latest.title : 'Multiple inquiries',
        primaryConversationId: latest.id,
        conversationIds: items.map((summary) => summary.id).toList(),
        lastMessageAt: latest.lastMessageAt,
      );
    }).toList();

    inquiries.sort((a, b) {
      final DateTime? first = a.lastMessageAt;
      final DateTime? second = b.lastMessageAt;
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return second.compareTo(first);
    });

    return inquiries;
  }
}

class AdminHomePage extends StatefulWidget {
  final VoidCallback onLogout;

  const AdminHomePage({super.key, required this.onLogout});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  List<AgentInquiry> _inquiries = const [];
  bool _isInboxLoading = true;
  RealtimeChannel? _inboxChannel;

  int get _unreadInquiryCount =>
      _inquiries.where((inquiry) => inquiry.isUnread).length;

  List<Property> get _properties => appPropertiesNotifier.value;

  @override
  void initState() {
    super.initState();
    appPropertiesNotifier.addListener(_refreshDashboard);
    unawaited(_loadInquiries());
    _subscribeToInboxUpdates();
  }

  @override
  void dispose() {
    appPropertiesNotifier.removeListener(_refreshDashboard);
    if (_inboxChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_inboxChannel!));
    }
    super.dispose();
  }

  void _refreshDashboard() {
    if (!mounted) return;
    setState(() {});
  }

  void _subscribeToInboxUpdates() {
    final SupabaseClient client = Supabase.instance.client;
    _inboxChannel = client
        .channel('agent-inbox-dashboard')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (!mounted) return;
            unawaited(_loadInquiries(showLoader: false));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'conversations',
          callback: (_) {
            if (!mounted) return;
            unawaited(_loadInquiries(showLoader: false));
          },
        )
        .subscribe();
  }

  Future<void> _loadInquiries({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isInboxLoading = true;
      });
    }

    try {
      final List<ConversationSummary> summaries =
          await MessagingService.fetchMyConversationSummaries();
      if (!mounted) return;
      setState(() {
        _inquiries = AgentInquiry.groupedFromConversationSummaries(summaries);
        _isInboxLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _inquiries = const [];
        _isInboxLoading = false;
      });
    }
  }

  Future<void> _openAddPropertyPage() async {
    final Property? newProperty = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PropertyFormPage()),
    );

    if (newProperty == null || !mounted) return;

    try {
      final Property createdProperty = await createProperty(newProperty);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${createdProperty.title} added successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add property: $e')));
    }
  }

  Future<void> _openManagePropertiesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManagePropertiesPage(
          properties: _properties,
          onUpdateProperty: _updatePropertyRecord,
          onDeleteProperty: _deletePropertyRecord,
        ),
      ),
    );

    if (!mounted) return;
  }

  Future<void> _openInboxPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AgentInboxPage(
          inquiries: _inquiries,
          onMarkAsRead: _markInquiryAsRead,
        ),
      ),
    );

    if (!mounted) return;
    await _loadInquiries(showLoader: false);
  }

  Future<void> _updatePropertyRecord(Property updatedProperty) async {
    await updateProperty(updatedProperty);
  }

  Future<void> _deletePropertyRecord(String propertyId) async {
    await deleteProperty(propertyId);
  }

  void _markInquiryAsRead(String inquiryId) {
    final int index = _inquiries.indexWhere(
      (inquiry) => inquiry.id == inquiryId,
    );

    if (index == -1 || !_inquiries[index].isUnread) return;

    setState(() {
      _inquiries[index] = _inquiries[index].copyWith(isUnread: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(
                Icons.add_home_work,
                color: Color(0xFF2E7D32),
              ),
              title: const Text('Add New Property'),
              subtitle: const Text('Create a new listing'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openAddPropertyPage,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.edit_note, color: Colors.orange),
              title: const Text('Manage Properties'),
              subtitle: Text('${_properties.length} listing(s) available'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openManagePropertiesPage,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.mail, color: Colors.blue),
              title: const Text('Agent Inbox'),
              subtitle: Text(
                _isInboxLoading
                    ? 'Loading inquiries...'
                    : '$_unreadInquiryCount unread inquiry(s)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openInboxPage,
            ),
          ),
        ],
      ),
    );
  }
}

class PropertyFormPage extends StatefulWidget {
  final Property? initialProperty;

  const PropertyFormPage({super.key, this.initialProperty});

  @override
  State<PropertyFormPage> createState() => _PropertyFormPageState();
}

class _PropertyFormPageState extends State<PropertyFormPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _priceController;
  late final TextEditingController _sizeController;
  late final TextEditingController _statusController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.initialProperty != null;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.initialProperty?.title ?? '',
    );
    _locationController = TextEditingController(
      text: widget.initialProperty?.location ?? '',
    );
    _priceController = TextEditingController(
      text: widget.initialProperty?.price ?? '',
    );
    _sizeController = TextEditingController(
      text: widget.initialProperty?.size ?? '',
    );
    _statusController = TextEditingController(
      text: widget.initialProperty?.tag ?? 'Active',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _sizeController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final int parsedPriceValue = _extractNumber(_priceController.text);
    final int parsedSizeValue = _extractNumber(_sizeController.text);

    final Property property = Property(
      id:
          widget.initialProperty?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      location: _locationController.text.trim(),
      price: _priceController.text.trim(),
      priceValue: parsedPriceValue > 0 ? parsedPriceValue : 0,
      size: _sizeController.text.trim(),
      sizeValue: parsedSizeValue > 0 ? parsedSizeValue : 0,
      tag: _statusController.text.trim(),
      imageColor: widget.initialProperty?.imageColor ?? _randomColor(),
    );

    Navigator.pop(context, property);
  }

  int _extractNumber(String input) {
    final String digitsOnly = input.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digitsOnly) ?? 0;
  }

  Color _randomColor() {
    final List<Color> colors = [
      const Color(0xFF9CCC65),
      const Color(0xFFA1887F),
      const Color(0xFF64B5F6),
      const Color(0xFFBA68C8),
      const Color(0xFFFFB74D),
    ];
    return colors[Random().nextInt(colors.length)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Property' : 'Add New Property'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Clean title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a clean title.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Grid coordinate',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a grid coordinate.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a price.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sizeController,
              decoration: const InputDecoration(
                labelText: 'Lot size',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a lot size.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _statusController,
              decoration: const InputDecoration(
                labelText: 'Card tag',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a card tag.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Save Changes' : 'Add Property'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManagePropertiesPage extends StatefulWidget {
  final List<Property> properties;
  final Future<void> Function(Property property) onUpdateProperty;
  final Future<void> Function(String propertyId) onDeleteProperty;

  const ManagePropertiesPage({
    super.key,
    required this.properties,
    required this.onUpdateProperty,
    required this.onDeleteProperty,
  });

  @override
  State<ManagePropertiesPage> createState() => _ManagePropertiesPageState();
}

class _ManagePropertiesPageState extends State<ManagePropertiesPage> {
  late List<Property> _properties;

  @override
  void initState() {
    super.initState();
    _properties = List<Property>.from(widget.properties);
  }

  Future<void> _editProperty(Property property) async {
    final Property? updatedProperty = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PropertyFormPage(initialProperty: property),
      ),
    );

    if (updatedProperty == null || !mounted) return;

    final int index = _properties.indexWhere(
      (item) => item.id == updatedProperty.id,
    );

    if (index == -1) return;

    setState(() {
      _properties[index] = updatedProperty;
    });
    await widget.onUpdateProperty(updatedProperty);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updatedProperty.title} updated successfully.')),
    );
  }

  Future<void> _deleteProperty(Property property) async {
    setState(() {
      _properties.removeWhere((item) => item.id == property.id);
    });
    await widget.onDeleteProperty(property.id);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${property.title} deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Properties')),
      body: _properties.isEmpty
          ? const Center(child: Text('No properties available.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _properties.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final Property property = _properties[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(property.title),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Grid: ${property.location}\n${property.price} • ${property.size}\nTag: ${property.tag}',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editProperty(property);
                        } else if (value == 'delete') {
                          _deleteProperty(property);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class AgentInboxPage extends StatefulWidget {
  final List<AgentInquiry> inquiries;
  final ValueChanged<String> onMarkAsRead;

  const AgentInboxPage({
    super.key,
    required this.inquiries,
    required this.onMarkAsRead,
  });

  @override
  State<AgentInboxPage> createState() => _AgentInboxPageState();
}

class _AgentInboxPageState extends State<AgentInboxPage> {
  late List<AgentInquiry> _inquiries;
  RealtimeChannel? _inboxChannel;

  @override
  void initState() {
    super.initState();
    _inquiries = List<AgentInquiry>.from(widget.inquiries);
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
      MaterialPageRoute(
        builder: (context) => InquiryDetailsPage(inquiry: inquiry),
      ),
    );

    await _refreshInquiries();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Inbox')),
      body: RefreshIndicator(
        onRefresh: _refreshInquiries,
        child: _inquiries.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No buyer inquiries yet.')),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _inquiries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final AgentInquiry inquiry = _inquiries[index];
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
  bool _isLoadingMessages = true;
  List<ConversationMessage> _messages = const [];
  RealtimeChannel? _messagesChannel;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _replyController = TextEditingController();
    _messagesScrollController = ScrollController();
    _subscribeToMessageUpdates();
    unawaited(_loadMessages(scrollToBottom: true));
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
    _messagesChannel = Supabase.instance.client
        .channel('agent-thread-${widget.inquiry.buyerId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (!mounted) return;
            unawaited(_loadMessages(scrollToBottom: true));
          },
        )
        .subscribe();
  }

  Future<void> _loadMessages({bool scrollToBottom = false}) async {
    try {
      final List<ConversationMessage> messages =
          await MessagingService.fetchConversationMessagesForConversations(
            widget.inquiry.conversationIds,
          );
      final int previousCount = _messages.length;
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _isLoadingMessages = false;
      });
      if (scrollToBottom || messages.length > previousCount) {
        _scrollToBottom();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMessages = false;
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

  Future<void> _sendReply() async {
    final String replyText = _replyController.text.trim();
    if (replyText.isEmpty || _isSending) return;

    final ConversationMessage optimisticMessage = ConversationMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: widget.inquiry.primaryConversationId,
      senderId: _currentUserId,
      body: replyText,
      createdAt: DateTime.now(),
      readAt: null,
    );

    setState(() {
      _isSending = true;
      _messages = [..._messages, optimisticMessage];
    });
    _replyController.clear();
    _scrollToBottom();

    try {
      await MessagingService.sendMessage(
        conversationId: widget.inquiry.primaryConversationId,
        body: replyText,
      );

      if (!mounted) return;
      await _loadMessages(scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      _replyController.text = replyText;
      setState(() {
        _messages = _messages
            .where((message) => message.id != optimisticMessage.id)
            .toList();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send reply: $e')));
    } finally {
      if (!mounted) return;
      setState(() {
        _isSending = false;
      });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to edit message: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete message: $e')));
    }
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
                        ? const Center(child: CircularProgressIndicator())
                        : _messages.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('No messages yet.')),
                            ],
                          )
                        : ListView.separated(
                            controller: _messagesScrollController,
                            itemCount: _messages.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final ConversationMessage message =
                                  _messages[index];
                              final bool isAgentMessage = message.isFrom(
                                _currentUserId,
                              );
                              final Color bubbleColor = isAgentMessage
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.secondaryContainer;
                              final Color textColor = isAgentMessage
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer;
                              final Color metaColor = isAgentMessage
                                  ? Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer
                                        .withValues(alpha: 0.75)
                                  : Theme.of(
                                      context,
                                    ).colorScheme.onSecondaryContainer;

                              return Align(
                                alignment: isAgentMessage
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: GestureDetector(
                                  onLongPress:
                                      isAgentMessage && !message.isPending
                                      ? () => _showMessageActions(message)
                                      : null,
                                  child: TweenAnimationBuilder<double>(
                                    key: ValueKey(message.id),
                                    tween: Tween(begin: 0, end: 1),
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(
                                            isAgentMessage
                                                ? (1 - value) * 18
                                                : -(1 - value) * 18,
                                            (1 - value) * 10,
                                          ),
                                          child: child,
                                        ),
                                      );
                                    },
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 320,
                                      ),
                                      child: Card(
                                        color: bubbleColor,
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
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
                                                    : _formatInboxTime(
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
                      child: _isSending
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
                              onPressed: _sendReply,
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
