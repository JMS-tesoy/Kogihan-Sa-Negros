import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/route_names.dart';
import '../../../agent_teams/presentation/screens/manage_agent_teams_screen.dart';
import '../../../location/data/datasources/negros_places_datasource.dart';
import '../../../messaging/data/services/messaging_service.dart';
import '../../../properties/data/datasources/shared_properties.dart';

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

List<AgentInquiry> _cachedAgentInquiries() {
  final List<ConversationSummary> cachedSummaries =
      MessagingService.getCachedConversationSummaries();
  if (cachedSummaries.isEmpty) return const [];
  return AgentInquiry.groupedFromConversationSummaries(cachedSummaries);
}

Route<T> _instantRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => child,
  );
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
      primaryConversationId:
          primaryConversationId ?? this.primaryConversationId,
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
        conversationTitle: titles.length <= 1
            ? latest.title
            : 'Multiple inquiries',
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
  final Future<void> Function(BuildContext context) onLogout;

  const AdminHomePage({super.key, required this.onLogout});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  List<AgentInquiry> _inquiries = const [];
  bool _isInboxLoading = true;
  RealtimeChannel? _inboxChannel;
  int _selectedDashboardActionTab = 1;
  int _dashboardActionTransitionDirection = 1;

  int get _unreadInquiryCount =>
      _inquiries.where((inquiry) => inquiry.isUnread).length;

  void _selectDashboardActionTab(int tabIndex) {
    if (_selectedDashboardActionTab == tabIndex) return;

    setState(() {
      _dashboardActionTransitionDirection =
          tabIndex > _selectedDashboardActionTab ? 1 : -1;
      _selectedDashboardActionTab = tabIndex;
    });
  }

  List<Property> get _properties => appPropertiesNotifier.value;

  @override
  void initState() {
    super.initState();
    appPropertiesNotifier.addListener(_refreshDashboard);
    final List<AgentInquiry> cachedInquiries = _cachedAgentInquiries();
    if (cachedInquiries.isNotEmpty) {
      _inquiries = cachedInquiries;
      _isInboxLoading = false;
    }
    unawaited(_loadInquiries(showLoader: cachedInquiries.isEmpty));
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
  }

  Future<void> _openInboxPage({
    AgentInboxFilter initialFilter = AgentInboxFilter.all,
  }) async {
    await Navigator.push(
      context,
      _instantRoute(
        AgentInboxPage(
          inquiries: _inquiries,
          onMarkAsRead: _markInquiryAsRead,
          initialFilter: initialFilter,
        ),
      ),
    );

    if (!mounted) return;
    await _loadInquiries(showLoader: false);
  }

  Future<void> _openUnreadInboxPage() async {
    await _openInboxPage(initialFilter: AgentInboxFilter.unread);
  }

  Future<void> _openAllThreadsPage() async {
    await _openInboxPage();
  }

  Future<void> _openManageTeamsPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ManageAgentTeamsScreen()),
    );
  }

  Future<void> _openTeamInboxPage() async {
    await Navigator.push(context, _instantRoute(const TeamInboxPage()));
  }

  Future<void> _openPersonalProfilePage() async {
    await Navigator.of(context).pushNamed(RouteNames.profile);
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

  Widget _buildDashboardActionCard({
    required BuildContext context,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: isLightTheme ? 0.12 : 0.2,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: accentColor, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badgeText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyActionSplitTabs(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Widget addNewPropertyCard = _buildDashboardActionCard(
      context: context,
      icon: Icons.add_home_work_rounded,
      accentColor: theme.colorScheme.primary,
      title: 'Add New Property',
      subtitle: 'Create and publish a new listing.',
      badgeText: 'Quick action',
      onTap: _openAddPropertyPage,
    );

    final Widget managePropertiesCard = _buildDashboardActionCard(
      context: context,
      icon: Icons.edit_note_rounded,
      accentColor: Colors.orange,
      title: 'Manage Properties',
      subtitle: 'Review and update your active listings.',
      badgeText: '${_properties.length} listing(s)',
      onTap: _openManagePropertiesPage,
    );

    final Widget manageTeamsCard = _buildDashboardActionCard(
      context: context,
      icon: Icons.admin_panel_settings_outlined,
      accentColor: Colors.teal,
      title: 'Manage Teams',
      subtitle: 'View members, handle join requests, and manage agent teams.',
      badgeText: 'Admin',
      onTap: _openManageTeamsPage,
    );

    final Widget buyerMessagesCard = _buildDashboardActionCard(
      context: context,
      icon: Icons.forum_rounded,
      accentColor: Colors.blue,
      title: 'Buyer Messages',
      subtitle: 'Open buyer inquiries and reply to property conversations.',
      badgeText: _isInboxLoading
          ? 'Loading messages...'
          : '$_unreadInquiryCount unread message(s)',
      onTap: _openAllThreadsPage,
    );

    final Widget teamInboxCard = _buildDashboardActionCard(
      context: context,
      icon: Icons.mark_chat_unread_outlined,
      accentColor: Colors.green,
      title: 'Team Inbox',
      subtitle: 'Open realtime internal messages for agent teams.',
      badgeText: 'Realtime chat',
      onTap: _openTeamInboxPage,
    );

    final bool isManageTeamSelected = _selectedDashboardActionTab == 0;
    final Widget selectedTabContent = isManageTeamSelected
        ? Column(
            key: const ValueKey<String>('manage-team-tab-content'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 126),
                child: manageTeamsCard,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 126),
                child: teamInboxCard,
              ),
            ],
          )
        : Column(
            key: const ValueKey<String>('manage-property-tab-content'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 126),
                child: addNewPropertyCard,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 126),
                child: managePropertiesCard,
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 126),
                child: buyerMessagesCard,
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: theme.brightness == Brightness.light ? 0.75 : 0.45,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              _buildPropertyActionTabButton(
                context: context,
                label: 'Manage Team',
                icon: Icons.admin_panel_settings_outlined,
                isSelected: isManageTeamSelected,
                onTap: () => _selectDashboardActionTab(0),
              ),
              const SizedBox(width: 4),
              _buildPropertyActionTabButton(
                context: context,
                label: 'Manage Property',
                icon: Icons.edit_note_rounded,
                isSelected: !isManageTeamSelected,
                onTap: () => _selectDashboardActionTab(1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            reverseDuration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final bool isIncomingChild = child.key == selectedTabContent.key;
              final double direction = _dashboardActionTransitionDirection
                  .toDouble();
              final Offset beginOffset = isIncomingChild
                  ? Offset(0.18 * direction, 0)
                  : Offset(-0.18 * direction, 0);
              final Animation<Offset> slideAnimation =
                  Tween<Offset>(begin: beginOffset, end: Offset.zero).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                      reverseCurve: Curves.easeInCubic,
                    ),
                  );

              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slideAnimation, child: child),
              );
            },
            layoutBuilder:
                (Widget? currentChild, List<Widget> previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[...previousChildren, ?currentChild],
                  );
                },
            child: selectedTabContent,
          ),
        ),
      ],
    );
  }

  Widget _buildPropertyActionTabButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final Color selectedBackground = theme.colorScheme.primary;
    final Color selectedForeground = theme.colorScheme.onPrimary;
    final Color unselectedForeground = theme.colorScheme.onSurfaceVariant;
    final BorderRadius borderRadius = BorderRadius.circular(16);

    return Expanded(
      child: AnimatedScale(
        scale: isSelected ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              decoration: BoxDecoration(
                color: isSelected ? selectedBackground : Colors.transparent,
                borderRadius: borderRadius,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: selectedBackground.withValues(
                            alpha: theme.brightness == Brightness.light
                                ? 0.22
                                : 0.12,
                          ),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? selectedForeground.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      size: 17,
                      color: isSelected
                          ? selectedForeground
                          : unselectedForeground,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? selectedForeground
                            : unselectedForeground,
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTile({
    required BuildContext context,
    required String value,
    required String label,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final ThemeData theme = Theme.of(context);
    final BorderRadius borderRadius = BorderRadius.circular(18);

    return Expanded(
      child: Material(
        color: theme.cardColor,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Tooltip(
              message: 'Personal Profile',
              child: Material(
                color: theme.colorScheme.primaryContainer,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openPersonalProfilePage,
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.person_rounded,
                      size: 19,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        title: const Text('Agent Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.onLogout(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Quick Overview',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A quick snapshot of your current dashboard activity.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildOverviewTile(
                context: context,
                value: '${_properties.length}',
                label: 'Listings',
                icon: Icons.home_work_rounded,
                accentColor: theme.colorScheme.primary,
                onTap: _openManagePropertiesPage,
              ),
              const SizedBox(width: 8),
              _buildOverviewTile(
                context: context,
                value: '$_unreadInquiryCount',
                label: 'Unread',
                icon: Icons.mark_email_unread_rounded,
                accentColor: Colors.blue,
                onTap: _openUnreadInboxPage,
              ),
              const SizedBox(width: 8),
              _buildOverviewTile(
                context: context,
                value: '${_inquiries.length}',
                label: 'Threads',
                icon: Icons.forum_rounded,
                accentColor: Colors.orange,
                onTap: _openAllThreadsPage,
              ),
            ],
          ),
          const SizedBox(height: 22),
          _buildPropertyActionSplitTabs(context),
        ],
      ),
    );
  }
}

class TeamChatTeam {
  const TeamChatTeam({
    required this.id,
    required this.name,
    required this.specialization,
    required this.logoUrl,
  });

  factory TeamChatTeam.fromMap(Map<String, dynamic> map) {
    return TeamChatTeam(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed Team',
      specialization: map['specialization'] as String? ?? '',
      logoUrl: map['logo_url'] as String?,
    );
  }

  final String id;
  final String name;
  final String specialization;
  final String? logoUrl;
}

class TeamChatMessage {
  const TeamChatMessage({
    required this.id,
    required this.teamId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentPath,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentSizeBytes,
  });

  factory TeamChatMessage.fromMap(Map<String, dynamic> map) {
    return TeamChatMessage(
      id: map['id'] as String? ?? '',
      teamId: map['team_id'] as String? ?? '',
      senderId: map['sender_id'] as String? ?? '',
      senderName: map['sender_name'] as String? ?? 'Agent',
      body: map['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      attachmentUrl: map['attachment_url'] as String?,
      attachmentPath: map['attachment_path'] as String?,
      attachmentName: map['attachment_name'] as String?,
      attachmentMimeType: map['attachment_mime_type'] as String?,
      attachmentSizeBytes: _parseAttachmentSize(map['attachment_size_bytes']),
    );
  }

  final String id;
  final String teamId;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentPath;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSizeBytes;

  bool get hasAttachment => (attachmentUrl ?? '').trim().isNotEmpty;
  bool get attachmentIsImage =>
      (attachmentMimeType ?? '').toLowerCase().startsWith('image/');
  String get attachmentDisplayName {
    final String name = (attachmentName ?? '').trim();
    return name.isNotEmpty ? name : 'Attachment';
  }
}

int? _parseAttachmentSize(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}

class TeamInboxPage extends StatefulWidget {
  const TeamInboxPage({super.key});

  @override
  State<TeamInboxPage> createState() => _TeamInboxPageState();
}

class _TeamInboxPageState extends State<TeamInboxPage> {
  final SupabaseClient _client = Supabase.instance.client;
  List<TeamChatTeam> _teams = const <TeamChatTeam>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadTeams());
  }

  Future<void> _loadTeams() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final List<TeamChatTeam> teams = await _fetchMyTeams();
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load team inbox. $e';
        _isLoading = false;
      });
    }
  }

  Future<List<TeamChatTeam>> _fetchMyTeams() async {
    final List<dynamic> rows = await _client
        .from('agent_teams')
        .select('id, name, specialization, logo_url')
        .order('name');

    return rows
        .map(
          (row) => TeamChatTeam.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .where((team) => team.id.isNotEmpty)
        .toList();
  }

  Future<void> _openTeamChat(TeamChatTeam team) async {
    await Navigator.push(
      context,
      _instantRoute(TeamConversationPage(team: team)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Team Inbox')),
      body: RefreshIndicator(onRefresh: _loadTeams, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loadTeams,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try Again'),
          ),
        ],
      );
    }

    if (_teams.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.groups_2_outlined,
            size: 46,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'No team inbox available yet.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Create at least one team before using the admin Team Inbox.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _teams.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final TeamChatTeam team = _teams[index];
        final String initial = team.name.trim().isNotEmpty
            ? team.name.trim()[0].toUpperCase()
            : 'T';

        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              backgroundImage: team.logoUrl != null && team.logoUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(team.logoUrl!)
                  : null,
              child: team.logoUrl == null || team.logoUrl!.isEmpty
                  ? Text(initial)
                  : null,
            ),
            title: Text(team.name),
            subtitle: Text(
              team.specialization.isEmpty
                  ? 'Open team realtime chat'
                  : team.specialization,
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openTeamChat(team),
          ),
        );
      },
    );
  }
}

class TeamConversationPage extends StatefulWidget {
  const TeamConversationPage({super.key, required this.team});

  final TeamChatTeam team;

  @override
  State<TeamConversationPage> createState() => _TeamConversationPageState();
}

class _TeamConversationPageState extends State<TeamConversationPage> {
  static const int _messageLimit = 80;

  final SupabaseClient _client = Supabase.instance.client;
  late final TextEditingController _messageController;
  late final ScrollController _scrollController;
  RealtimeChannel? _teamMessagesChannel;
  List<TeamChatMessage> _messages = const <TeamChatMessage>[];
  bool _isLoading = true;
  bool _isSending = false;
  bool _isAttaching = false;
  String? _error;

  String get _currentUserId => _client.auth.currentUser?.id ?? '';

  String get _currentUserDisplayName {
    final User? user = _client.auth.currentUser;
    final Map<String, dynamic> data = user?.userMetadata ?? const {};
    final String? fullName = data['full_name'] as String?;
    final String? name = data['name'] as String?;
    final String? email = user?.email;

    return (fullName?.trim().isNotEmpty ?? false)
        ? fullName!.trim()
        : (name?.trim().isNotEmpty ?? false)
        ? name!.trim()
        : (email?.trim().isNotEmpty ?? false)
        ? email!.trim()
        : 'Agent';
  }

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
      unawaited(_client.removeChannel(_teamMessagesChannel!));
    }
    super.dispose();
  }

  void _subscribeToTeamMessages() {
    _teamMessagesChannel = _client
        .channel('team-inbox-${widget.team.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'team_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'team_id',
            value: widget.team.id,
          ),
          callback: (_) {
            if (!mounted) return;
            unawaited(_loadMessages(scrollToBottom: true, showLoader: false));
          },
        )
        .subscribe();
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
      final List<dynamic> rows = await _client
          .from('team_messages')
          .select(
            'id, team_id, sender_id, sender_name, body, created_at, attachment_url, attachment_path, attachment_name, attachment_mime_type, attachment_size_bytes',
          )
          .eq('team_id', widget.team.id)
          .order('created_at', ascending: false)
          .limit(_messageLimit);

      final List<TeamChatMessage> messages = rows
          .map(
            (row) =>
                TeamChatMessage.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList()
          .reversed
          .toList();

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
    if ((body.isEmpty && attachment == null) ||
        _isSending ||
        _currentUserId.isEmpty) {
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
      final Map<String, dynamic> insertPayload = <String, dynamic>{
        'team_id': widget.team.id,
        'sender_id': _currentUserId,
        'sender_name': _currentUserDisplayName,
        'body': bodyToSend,
        if (attachment != null) ...attachment.toMessageColumns(),
      };

      final Map<String, dynamic> row = await _client
          .from('team_messages')
          .insert(insertPayload)
          .select(
            'id, team_id, sender_id, sender_name, body, created_at, attachment_url, attachment_path, attachment_name, attachment_mime_type, attachment_size_bytes',
          )
          .single();

      final TeamChatMessage sentMessage = TeamChatMessage.fromMap(row);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send team message: $e')),
      );
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to attach file: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open attachment.')),
      );
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
    final String timeLabel = _formatInboxTime(message.createdAt);

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

class PropertyFormPage extends StatefulWidget {
  final Property? initialProperty;

  const PropertyFormPage({super.key, this.initialProperty});

  @override
  State<PropertyFormPage> createState() => _PropertyFormPageState();
}

class _UploadedImageThumbnail extends StatelessWidget {
  const _UploadedImageThumbnail({
    required this.url,
    required this.isMainImage,
    required this.onRemove,
  });

  final String url;
  final bool isMainImage;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ImageProvider<Object> imageProvider = url.startsWith('http')
        ? CachedNetworkImageProvider(url)
        : AssetImage(url);

    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_not_supported_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
          ),
          if (isMainImage)
            Positioned(
              left: 4,
              bottom: 4,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    'Main',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PropertyFormPageState extends State<PropertyFormPage> {
  static const List<String> _titleStatusOptions = [
    'Clean Title',
    'Transfer Certificate of Title',
    'Tax Declaration',
    'Mother Title',
    'CLOA',
    'Pending Verification',
  ];

  late final TextEditingController _referenceCodeController;
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _priceController;
  late final TextEditingController _sizeController;
  late final TextEditingController _statusController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _thumbnailUrlController;
  late final TextEditingController _galleryImageUrlsController;
  late final TextEditingController _boundaryCoordinatesController;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingImage = false;
  bool _isLoadingTeamOptions = true;
  List<_ListingTeamOption> _teamOptions = const <_ListingTeamOption>[];
  String? _selectedAgentTeamId;
  late String _selectedTitleStatus;

  bool get _isEditing => widget.initialProperty != null;
  String get _previewReferenceCode {
    final String value = _referenceCodeController.text.trim();
    return value.isEmpty ? 'Listing code' : value;
  }

  String get _previewTitle {
    final String value = _titleController.text.trim();
    return value.isEmpty ? 'Property Title' : value;
  }

  String get _previewLocation {
    final String value = _locationController.text.trim();
    return value.isEmpty ? 'Grid coordinate' : value;
  }

  String get _previewPrice {
    final String value = _priceController.text.trim();
    return value.isEmpty ? '₱0' : value;
  }

  String get _previewSize {
    final String value = _sizeController.text.trim();
    return value.isEmpty ? 'Lot size not set' : value;
  }

  String get _previewTag {
    final String value = _statusController.text.trim();
    return value.isEmpty ? 'Active' : value;
  }

  String get _previewTitleStatus {
    final String value = _selectedTitleStatus.trim();
    return value.isEmpty ? 'Title status not set' : value;
  }

  String get _previewDescription {
    final String value = _descriptionController.text.trim();
    return value.isEmpty
        ? 'Add a property description so buyers understand the land offering.'
        : value;
  }

  String? get _selectedTeamName {
    for (final _ListingTeamOption team in _teamOptions) {
      if (team.id == _selectedAgentTeamId) return team.name;
    }
    return widget.initialProperty?.agentTeamName;
  }

  String? get _previewImageSource {
    final String thumbnailUrl = _thumbnailUrlController.text.trim();
    if (thumbnailUrl.isNotEmpty) return thumbnailUrl;

    final String imageUrl = _imageUrlController.text.trim();
    return imageUrl.isEmpty ? null : imageUrl;
  }

  List<String> _galleryImageUrlsFromText() {
    final List<String> urls = <String>[];
    for (final String line in _galleryImageUrlsController.text.split('\n')) {
      final String url = line.trim();
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
    return urls;
  }

  List<String> get _mediaPreviewUrls {
    final List<String> urls = <String>[];

    void addUrl(String? value) {
      final String url = (value ?? '').trim();
      if (url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }

    final String thumbnailUrl = _thumbnailUrlController.text.trim();
    final String imageUrl = _imageUrlController.text.trim();
    addUrl(thumbnailUrl.isNotEmpty ? thumbnailUrl : imageUrl);
    for (final String url in _galleryImageUrlsFromText()) {
      addUrl(url);
    }
    return urls;
  }

  void _addGalleryImageUrl(String imageUrl) {
    final List<String> urls = _galleryImageUrlsFromText();
    if (!urls.contains(imageUrl)) {
      urls.add(imageUrl);
    }
    _galleryImageUrlsController.text = urls.join('\n');
  }

  void _removeMediaPreviewUrl(String imageUrl) {
    final String normalizedUrl = imageUrl.trim();
    final bool isMainImage =
        _imageUrlController.text.trim() == normalizedUrl ||
        _thumbnailUrlController.text.trim() == normalizedUrl;
    if (isMainImage) {
      _imageUrlController.clear();
      _thumbnailUrlController.clear();
    }

    final List<String> urls = _galleryImageUrlsFromText()
        .where((url) => url != normalizedUrl)
        .toList();
    _galleryImageUrlsController.text = urls.join('\n');
    setState(() {});
  }

  ImageProvider<Object>? get _previewImageProvider {
    final String? imageSource = _previewImageSource;
    if (imageSource == null) return null;
    if (imageSource.startsWith('http')) {
      return CachedNetworkImageProvider(imageSource);
    }
    return AssetImage(imageSource);
  }

  Widget _buildSectionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildCompactFieldRow({required Widget left, required Widget right}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(children: [left, const SizedBox(height: 12), right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 8),
            Expanded(child: right),
          ],
        );
      },
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    String? helperText,
    int? maxLines,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: (_) => setState(() {}),
      minLines: maxLines != null && maxLines > 1 ? maxLines : 1,
      maxLines: maxLines ?? 1,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      validator: validator,
    );
  }

  Widget _buildUploadedImagePreviewStrip(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> urls = _mediaPreviewUrls;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Uploaded images',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final String url = urls[index];
              return _UploadedImageThumbnail(
                url: url,
                isMainImage: index == 0,
                onRemove: () => _removeMediaPreviewUrl(url),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBoundaryGuidelines(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Start at any land corner, then enter the next corner beside it. '
            'You may paste the corners in any order, then tap Auto-arrange. '
            'The app sorts simple lot shapes around the center before saving. '
            'The map marker uses the boundary center when these points are added.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionField({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String? helperText,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      validator: (selectedValue) {
        if (selectedValue == null || selectedValue.trim().isEmpty) {
          return 'Please select a title status.';
        }
        return null;
      },
    );
  }

  Widget _buildTeamSelectionField(BuildContext context) {
    final bool selectedTeamInOptions =
        _selectedAgentTeamId == null ||
        _teamOptions.any((team) => team.id == _selectedAgentTeamId);
    return DropdownButtonFormField<String?>(
      initialValue: selectedTeamInOptions ? _selectedAgentTeamId : null,
      onChanged: _isLoadingTeamOptions
          ? null
          : (value) {
              setState(() {
                _selectedAgentTeamId = value;
              });
            },
      decoration: InputDecoration(
        labelText: 'Agent team',
        helperText: _isLoadingTeamOptions
            ? 'Loading teams...'
            : 'Optional. Shows this team on property details.',
        prefixIcon: const Icon(Icons.groups_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      ),
      items: <DropdownMenuItem<String?>>[
        const DropdownMenuItem<String?>(value: null, child: Text('No team')),
        ..._teamOptions.map(
          (team) => DropdownMenuItem<String?>(
            value: team.id,
            child: Text(team.name, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
    );
  }

  Future<void> _loadTeamOptions() async {
    try {
      final List<dynamic> rows = await Supabase.instance.client
          .from('agent_teams')
          .select('id, name')
          .order('name');

      if (!mounted) return;
      setState(() {
        _teamOptions = rows
            .map(
              (row) => _ListingTeamOption.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        _isLoadingTeamOptions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _teamOptions = const <_ListingTeamOption>[];
        _isLoadingTeamOptions = false;
      });
    }
  }

  Map<String, List<NegrosPlace>> _groupNegrosPlacesByProvince(
    List<NegrosPlace> places,
  ) {
    final Map<String, List<NegrosPlace>> groupedPlaces =
        <String, List<NegrosPlace>>{};

    for (final NegrosPlace place in places) {
      final String province = place.province.trim().isEmpty
          ? 'Other Areas'
          : place.province.trim();
      groupedPlaces.putIfAbsent(province, () => <NegrosPlace>[]).add(place);
    }

    for (final List<NegrosPlace> provincePlaces in groupedPlaces.values) {
      provincePlaces.sort(
        (first, second) => first.placeName.compareTo(second.placeName),
      );
    }

    return groupedPlaces;
  }

  Future<void> _pickNegrosPlaceForLocation() async {
    final List<NegrosPlace> places = List<NegrosPlace>.from(
      appNegrosPlacesNotifier.value,
    );
    if (places.isEmpty) return;

    final Map<String, List<NegrosPlace>> groupedPlaces =
        _groupNegrosPlacesByProvince(places);

    final NegrosPlace? selectedPlace = await showModalBottomSheet<NegrosPlace>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.72,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Text(
                  'Pick Negros Place',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a place to fill this listing location with map coordinates.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ...groupedPlaces.entries.map((entry) {
                  final List<NegrosPlace> provincePlaces = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      leading: const Icon(Icons.location_city_outlined),
                      title: Text(entry.key),
                      subtitle: Text('${provincePlaces.length} places'),
                      children: provincePlaces
                          .map((place) {
                            return ListTile(
                              dense: true,
                              title: Text(place.placeName),
                              subtitle: Text(place.location),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () =>
                                  Navigator.of(sheetContext).pop(place),
                            );
                          })
                          .toList(growable: false),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (selectedPlace == null) return;

    setState(() {
      _locationController.text = selectedPlace.location;
    });
  }

  Widget _buildPreviewCard(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ImageProvider<Object>? imageProvider = _previewImageProvider;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: 132,
              width: double.infinity,
              child: imageProvider == null
                  ? Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF60A5FA)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: Colors.white,
                              size: 42,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Image preview will appear here',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Center(
                            child: Text(
                              'Unable to load image preview',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.pin_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _previewReferenceCode,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _previewTag,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _previewPrice,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _previewTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _previewLocation,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Chip(
                      label: Text(_previewSize),
                      avatar: const Icon(Icons.straighten, size: 18),
                    ),
                    Chip(
                      label: Text(_previewTitleStatus),
                      avatar: const Icon(Icons.verified_outlined, size: 18),
                    ),
                    Chip(
                      label: Text(
                        _previewImageSource == null
                            ? 'No image yet'
                            : 'Image attached',
                      ),
                      avatar: const Icon(Icons.image_outlined, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _previewDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<_OptimizedPropertyImages> _optimizePropertyImages(
    Uint8List bytes,
  ) async {
    final Uint8List detailBytes = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1600,
      minHeight: 1200,
      quality: 72,
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,
    );
    final Uint8List thumbnailBytes =
        await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 560,
          minHeight: 420,
          quality: 64,
          format: CompressFormat.jpeg,
          autoCorrectionAngle: true,
        );

    if (detailBytes.isEmpty || thumbnailBytes.isEmpty) {
      throw const FormatException('Unsupported image format.');
    }

    return _OptimizedPropertyImages(
      detailBytes: detailBytes,
      thumbnailBytes: thumbnailBytes,
    );
  }

  Future<void> _pickAndUploadPropertyImage() async {
    if (_isUploadingImage) return;

    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again before uploading.')),
      );
      return;
    }

    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 72,
      maxWidth: 1600,
      maxHeight: 1200,
    );

    if (pickedFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final Uint8List bytes = await pickedFile.readAsBytes();
      final _OptimizedPropertyImages optimizedImages =
          await _optimizePropertyImages(bytes);
      final int uploadTimestamp = DateTime.now().millisecondsSinceEpoch;
      final String detailFilePath = '${user.id}/$uploadTimestamp-detail.jpg';
      final String thumbnailFilePath = '${user.id}/$uploadTimestamp-thumb.jpg';

      await Supabase.instance.client.storage
          .from('property-images')
          .uploadBinary(
            detailFilePath,
            optimizedImages.detailBytes,
            fileOptions: FileOptions(
              cacheControl: '604800',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      await Supabase.instance.client.storage
          .from('property-images')
          .uploadBinary(
            thumbnailFilePath,
            optimizedImages.thumbnailBytes,
            fileOptions: FileOptions(
              cacheControl: '604800',
              upsert: true,
              contentType: 'image/jpeg',
            ),
          );

      final String publicUrl = Supabase.instance.client.storage
          .from('property-images')
          .getPublicUrl(detailFilePath);
      final String thumbnailPublicUrl = Supabase.instance.client.storage
          .from('property-images')
          .getPublicUrl(thumbnailFilePath);

      setState(() {
        if (_imageUrlController.text.trim().isEmpty) {
          _imageUrlController.text = publicUrl;
          _thumbnailUrlController.text = thumbnailPublicUrl;
        } else {
          _addGalleryImageUrl(publicUrl);
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Property image uploaded and optimized successfully.'),
        ),
      );
    } on StorageException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: ${error.message}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected upload error: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _referenceCodeController = TextEditingController(
      text: widget.initialProperty?.referenceCode ?? '',
    );
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
    _selectedTitleStatus =
        widget.initialProperty?.titleStatus.trim().isNotEmpty == true
        ? widget.initialProperty!.titleStatus
        : _titleStatusOptions.first;
    _descriptionController = TextEditingController(
      text: widget.initialProperty?.description ?? '',
    );
    _imageUrlController = TextEditingController(
      text: widget.initialProperty?.imageUrl ?? '',
    );
    _thumbnailUrlController = TextEditingController(
      text: widget.initialProperty?.thumbnailUrl ?? '',
    );
    _galleryImageUrlsController = TextEditingController(
      text: widget.initialProperty?.galleryImageUrls.join('\n') ?? '',
    );
    _boundaryCoordinatesController = TextEditingController(
      text: widget.initialProperty?.boundaryCoordinates ?? '',
    );
    _selectedAgentTeamId = widget.initialProperty?.agentTeamId;
    unawaited(_loadTeamOptions());
  }

  @override
  void dispose() {
    _referenceCodeController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    _priceController.dispose();
    _sizeController.dispose();
    _statusController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _thumbnailUrlController.dispose();
    _galleryImageUrlsController.dispose();
    _boundaryCoordinatesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final int parsedPriceValue = _extractNumber(_priceController.text);
    final int parsedSizeValue = _extractNumber(_sizeController.text);
    final String? arrangedBoundaryCoordinates =
        _arrangedBoundaryCoordinatesText();

    final Property property = Property(
      id:
          widget.initialProperty?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      referenceCode: _referenceCodeController.text.trim(),
      title: _titleController.text.trim(),
      location: _locationController.text.trim(),
      price: _priceController.text.trim(),
      priceValue: parsedPriceValue > 0 ? parsedPriceValue : 0,
      size: _sizeController.text.trim(),
      sizeValue: parsedSizeValue > 0 ? parsedSizeValue : 0,
      tag: _statusController.text.trim(),
      titleStatus: _selectedTitleStatus,
      description: _descriptionController.text.trim(),
      imageColor: widget.initialProperty?.imageColor ?? _randomColor(),
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      thumbnailUrl: _thumbnailUrlController.text.trim().isEmpty
          ? null
          : _thumbnailUrlController.text.trim(),
      galleryImageUrls: _galleryImageUrlsFromText(),
      boundaryCoordinates: arrangedBoundaryCoordinates,
      agentId:
          widget.initialProperty?.agentId ??
          Supabase.instance.client.auth.currentUser?.id,
      agentTeamId: _selectedAgentTeamId,
      agentTeamName: _selectedTeamName,
    );

    Navigator.pop(context, property);
  }

  List<List<double>> _parseCoordinatePairs(String value) {
    final String normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return const <List<double>>[];

    if (RegExp(r'''['"′″]''').hasMatch(normalized)) {
      return const <List<double>>[];
    }

    final List<RegExpMatch> matches = RegExp(
      r'([-+]?\d+(?:\.\d+)?)\s*°?\s*([NSEW])?',
    ).allMatches(normalized).toList(growable: false);
    if (matches.length < 2) return const <List<double>>[];

    final List<List<double>> coordinatePairs = <List<double>>[];
    for (int index = 0; index + 1 < matches.length; index += 2) {
      double? latitude = double.tryParse(matches[index].group(1)!);
      double? longitude = double.tryParse(matches[index + 1].group(1)!);
      if (latitude == null || longitude == null) continue;

      final String? latitudeDirection = matches[index].group(2);
      final String? longitudeDirection = matches[index + 1].group(2);
      if (latitudeDirection == 'S') latitude = -latitude.abs();
      if (longitudeDirection == 'W') longitude = -longitude.abs();

      if (latitude < -90 || latitude > 90) continue;
      if (longitude < -180 || longitude > 180) continue;

      coordinatePairs.add(<double>[latitude, longitude]);
    }

    return coordinatePairs;
  }

  List<Offset> _boundaryPointsFromText(String value) {
    final List<Offset> parsedPoints = _parseCoordinatePairs(
      value,
    ).map((pair) => Offset(pair[1], pair[0])).toList(growable: true);

    if (parsedPoints.length > 1 &&
        _sameBoundaryPoint(parsedPoints.first, parsedPoints.last)) {
      parsedPoints.removeLast();
    }

    final List<Offset> uniquePoints = <Offset>[];
    for (final Offset point in parsedPoints) {
      if (!uniquePoints.any((item) => _sameBoundaryPoint(item, point))) {
        uniquePoints.add(point);
      }
    }

    return uniquePoints;
  }

  bool _sameBoundaryPoint(Offset first, Offset second) {
    const double tolerance = 0.0000001;
    return (first.dx - second.dx).abs() < tolerance &&
        (first.dy - second.dy).abs() < tolerance;
  }

  double _boundaryTurn(Offset first, Offset second, Offset third) {
    return (second.dx - first.dx) * (third.dy - first.dy) -
        (second.dy - first.dy) * (third.dx - first.dx);
  }

  bool _pointIsOnBoundarySegment(Offset point, Offset start, Offset end) {
    const double tolerance = 0.0000001;
    return point.dx >= min(start.dx, end.dx) - tolerance &&
        point.dx <= max(start.dx, end.dx) + tolerance &&
        point.dy >= min(start.dy, end.dy) - tolerance &&
        point.dy <= max(start.dy, end.dy) + tolerance &&
        _boundaryTurn(start, end, point).abs() < tolerance;
  }

  bool _boundarySegmentsIntersect(
    Offset firstStart,
    Offset firstEnd,
    Offset secondStart,
    Offset secondEnd,
  ) {
    const double tolerance = 0.0000001;
    final double turnOne = _boundaryTurn(firstStart, firstEnd, secondStart);
    final double turnTwo = _boundaryTurn(firstStart, firstEnd, secondEnd);
    final double turnThree = _boundaryTurn(secondStart, secondEnd, firstStart);
    final double turnFour = _boundaryTurn(secondStart, secondEnd, firstEnd);

    if (turnOne.abs() < tolerance &&
        _pointIsOnBoundarySegment(secondStart, firstStart, firstEnd)) {
      return true;
    }
    if (turnTwo.abs() < tolerance &&
        _pointIsOnBoundarySegment(secondEnd, firstStart, firstEnd)) {
      return true;
    }
    if (turnThree.abs() < tolerance &&
        _pointIsOnBoundarySegment(firstStart, secondStart, secondEnd)) {
      return true;
    }
    if (turnFour.abs() < tolerance &&
        _pointIsOnBoundarySegment(firstEnd, secondStart, secondEnd)) {
      return true;
    }

    return (turnOne > 0) != (turnTwo > 0) && (turnThree > 0) != (turnFour > 0);
  }

  bool _boundaryHasCrossingLines(List<Offset> points) {
    for (int firstIndex = 0; firstIndex < points.length; firstIndex++) {
      final int firstNextIndex = (firstIndex + 1) % points.length;
      final Offset firstStart = points[firstIndex];
      final Offset firstEnd = points[firstNextIndex];

      for (
        int secondIndex = firstIndex + 1;
        secondIndex < points.length;
        secondIndex++
      ) {
        final int secondNextIndex = (secondIndex + 1) % points.length;
        final bool sharesCorner =
            firstIndex == secondIndex ||
            firstIndex == secondNextIndex ||
            firstNextIndex == secondIndex ||
            firstNextIndex == secondNextIndex;
        if (sharesCorner) continue;

        if (_boundarySegmentsIntersect(
          firstStart,
          firstEnd,
          points[secondIndex],
          points[secondNextIndex],
        )) {
          return true;
        }
      }
    }
    return false;
  }

  List<Offset> _autoArrangeBoundaryPoints(List<Offset> points) {
    if (points.length < 3) return points;

    double longitudeTotal = 0;
    double latitudeTotal = 0;
    for (final Offset point in points) {
      longitudeTotal += point.dx;
      latitudeTotal += point.dy;
    }

    final Offset center = Offset(
      longitudeTotal / points.length,
      latitudeTotal / points.length,
    );
    final List<Offset> arrangedPoints = List<Offset>.from(points);
    arrangedPoints.sort((first, second) {
      final double firstAngle = atan2(
        first.dy - center.dy,
        first.dx - center.dx,
      );
      final double secondAngle = atan2(
        second.dy - center.dy,
        second.dx - center.dx,
      );
      return firstAngle.compareTo(secondAngle);
    });

    return arrangedPoints;
  }

  String _formatBoundaryCoordinate(double value) {
    return value
        .toStringAsFixed(7)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _boundaryTextFromPoints(List<Offset> points) {
    return points
        .map(
          (point) =>
              '${_formatBoundaryCoordinate(point.dy)}, ${_formatBoundaryCoordinate(point.dx)}',
        )
        .join('\n');
  }

  String? _arrangedBoundaryCoordinatesText() {
    final String normalized = _boundaryCoordinatesController.text.trim();
    if (normalized.isEmpty) return null;

    final List<Offset> points = _boundaryPointsFromText(normalized);
    if (points.length < 3) return normalized;

    return _boundaryTextFromPoints(_autoArrangeBoundaryPoints(points));
  }

  void _autoArrangeBoundaryCoordinates() {
    final String? arrangedText = _arrangedBoundaryCoordinatesText();
    if (arrangedText == null) return;

    _boundaryCoordinatesController.text = arrangedText;
    setState(() {});
    _formKey.currentState?.validate();
  }

  String? _validateBoundaryCoordinates(String? value) {
    final String normalized = (value ?? '').trim();
    if (normalized.isEmpty) return null;

    final List<Offset> points = _boundaryPointsFromText(normalized);
    if (points.length < 3) {
      return 'Add at least 3 valid latitude, longitude points.';
    }
    final List<Offset> arrangedPoints = _autoArrangeBoundaryPoints(points);
    if (_boundaryHasCrossingLines(arrangedPoints)) {
      return 'Auto-arrange could not fix this shape. Check the corner points.';
    }
    return null;
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
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Property' : 'Add New Property'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.78),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing ? 'Update Listing' : 'Create New Listing',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill the form, preview it, then save.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildPreviewCard(context),
            const SizedBox(height: 12),
            _buildSectionCard(
              context: context,
              title: 'Listing Identity',
              subtitle:
                  'Add the core listing details the agent should track and publish.',
              children: [
                _buildCompactFieldRow(
                  left: _buildFormField(
                    controller: _referenceCodeController,
                    label: 'Listing code',
                    hintText: 'LF-000120008',
                    icon: Icons.pin_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a listing code.';
                      }
                      return null;
                    },
                  ),
                  right: _buildFormField(
                    controller: _titleController,
                    label: 'Clean title',
                    hintText: 'Prime Residential Lot',
                    icon: Icons.title_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a clean title.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _locationController,
                  label: 'Location / area',
                  hintText: 'Example: Dumaguete City or 9.3077, 123.3054',
                  icon: Icons.location_on_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a location or area.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _pickNegrosPlaceForLocation,
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Pick from Negros places'),
                  ),
                ),
                const SizedBox(height: 12),
                _buildCompactFieldRow(
                  left: _buildFormField(
                    controller: _priceController,
                    label: 'Price',
                    hintText: '₱1,200,000',
                    icon: Icons.payments_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a price.';
                      }
                      return null;
                    },
                  ),
                  right: _buildFormField(
                    controller: _sizeController,
                    label: 'Lot size',
                    hintText: '500 sqm',
                    icon: Icons.straighten_rounded,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a lot size.';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _buildCompactFieldRow(
                  left: _buildFormField(
                    controller: _statusController,
                    label: 'Card tag',
                    hintText: 'Featured',
                    icon: Icons.sell_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a card tag.';
                      }
                      return null;
                    },
                  ),
                  right: _buildSelectionField(
                    context: context,
                    label: 'Title status',
                    icon: Icons.verified_outlined,
                    value: _selectedTitleStatus,
                    items: _titleStatusOptions,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedTitleStatus = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              context: context,
              title: 'Agent Team',
              subtitle:
                  'Choose which verified team should appear on this listing.',
              children: [_buildTeamSelectionField(context)],
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              context: context,
              title: 'Listing Content',
              subtitle:
                  'Describe the land clearly so buyers understand the offer before they inquire.',
              children: [
                _buildFormField(
                  controller: _descriptionController,
                  label: 'Description',
                  hintText:
                      'Describe access, terrain, nearby landmarks, ideal use, and key selling points.',
                  icon: Icons.description_outlined,
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a property description.';
                    }
                    return null;
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              context: context,
              title: 'Map Boundary',
              subtitle:
                  'Optional. Add surveyed lot corners so buyers can see the land outline on the map.',
              children: [
                _buildBoundaryGuidelines(context),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _boundaryCoordinatesController,
                  label: 'Boundary coordinates',
                  hintText:
                      '9.3077, 123.3054\n9.3078, 123.3060\n9.3071, 123.3061\n9.3070, 123.3055',
                  icon: Icons.polyline_outlined,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  helperText:
                      'At least 3 points. One corner per line. The first point is closed automatically.',
                  validator: _validateBoundaryCoordinates,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _autoArrangeBoundaryCoordinates,
                    icon: const Icon(Icons.reorder_rounded),
                    label: const Text('Auto-arrange points'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSectionCard(
              context: context,
              title: 'Media',
              subtitle:
                  'Attach an image URL to make the listing preview more complete.',
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingImage
                        ? null
                        : _pickAndUploadPropertyImage,
                    icon: _isUploadingImage
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_upload_outlined),
                    label: Text(
                      _isUploadingImage
                          ? 'Uploading image...'
                          : 'Upload Image From Device',
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                ),
                if (_mediaPreviewUrls.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildUploadedImagePreviewStrip(context),
                ],
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _imageUrlController,
                  label: 'Image URL (optional)',
                  hintText: 'https://example.com/property.jpg',
                  icon: Icons.image_outlined,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _thumbnailUrlController,
                  label: 'Thumbnail URL (optional)',
                  hintText: 'https://example.com/property-thumb.jpg',
                  icon: Icons.photo_size_select_small_outlined,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: _galleryImageUrlsController,
                  label: 'Gallery image URLs (optional)',
                  hintText:
                      'https://example.com/gallery-1.jpg\nhttps://example.com/gallery-2.jpg',
                  icon: Icons.photo_library_outlined,
                  keyboardType: TextInputType.multiline,
                  maxLines: 4,
                  helperText:
                      'One image URL per line. These appear as right-side thumbnails on property details.',
                ),
                if (_imageUrlController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _imageUrlController.clear();
                          _thumbnailUrlController.clear();
                          _galleryImageUrlsController.clear();
                        });
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove image'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
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
  final Set<String> _warmedPropertyImageIds = <String>{};

  ImageProvider<Object>? _managePropertyImageProvider(Property property) {
    final String? imageUrl = resolvePropertyImageUrl(
      property,
      preferThumbnail: true,
      targetWidth: 720,
    );
    if (imageUrl == null || imageUrl.isEmpty) return null;
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImageProvider(imageUrl);
    }
    return AssetImage(imageUrl);
  }

  void _warmInitialPropertyImages() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final Property property in _properties.take(4)) {
        final ImageProvider<Object>? imageProvider =
            _managePropertyImageProvider(property);
        if (imageProvider == null) continue;
        if (_warmedPropertyImageIds.add(property.id)) {
          unawaited(precacheImage(imageProvider, context));
        }
      }
    });
  }

  Widget _buildManagePropertyCard(BuildContext context, Property property) {
    final ThemeData theme = Theme.of(context);
    final ImageProvider<Object>? imageProvider = _managePropertyImageProvider(
      property,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 88,
            width: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(
                  child: imageProvider != null
                      ? Image(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: theme.colorScheme.primaryContainer,
                              child: Icon(
                                Icons.landscape_rounded,
                                color: theme.colorScheme.onPrimaryContainer,
                                size: 34,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: theme.colorScheme.primaryContainer,
                          child: Icon(
                            Icons.landscape_rounded,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 34,
                          ),
                        ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      property.tag,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          property.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.location,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${property.price} • ${property.size}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          property.titleStatus,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _editProperty(property),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size.fromHeight(38),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Edit'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () => _deleteProperty(property),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size.fromHeight(38),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _properties = List<Property>.from(widget.properties);
    _warmInitialPropertyImages();
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
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${updatedProperty.title} updated successfully.')),
    );
  }

  Future<void> _deleteProperty(Property property) async {
    setState(() {
      _properties.removeWhere((item) => item.id == property.id);
    });
    await widget.onDeleteProperty(property.id);
    if (!mounted) return;

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
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 292,
              ),
              itemCount: _properties.length,
              itemBuilder: (context, index) {
                final Property property = _properties[index];
                return _buildManagePropertyCard(context, property);
              },
            ),
    );
  }
}

enum AgentInboxFilter { all, unread }

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
        : 'Agent Inbox';
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
        : _cachedAgentInquiries();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send reply: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to attach file: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open attachment.')),
      );
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

class _OptimizedPropertyImages {
  const _OptimizedPropertyImages({
    required this.detailBytes,
    required this.thumbnailBytes,
  });

  final Uint8List detailBytes;
  final Uint8List thumbnailBytes;
}

class _ListingTeamOption {
  const _ListingTeamOption({required this.id, required this.name});

  factory _ListingTeamOption.fromJson(Map<String, dynamic> json) {
    return _ListingTeamOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Agent Team',
    );
  }

  final String id;
  final String name;
}

class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({super.key});

  static Future<void> _noopLogout(BuildContext context) async {}

  @override
  Widget build(BuildContext context) {
    return AdminHomePage(onLogout: _noopLogout);
  }
}
