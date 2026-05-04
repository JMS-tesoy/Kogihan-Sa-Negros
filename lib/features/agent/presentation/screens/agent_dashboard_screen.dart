import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/route_names.dart';
import '../../../agent_teams/presentation/screens/manage_agent_teams_screen.dart';
import '../../../agent_teams/presentation/screens/team_inbox_screen.dart';
import '../../../messaging/data/services/messaging_service.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import 'manage_properties_page.dart';
import 'property_form_page.dart';

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

class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({super.key});

  static Future<void> _noopLogout(BuildContext context) async {}

  @override
  Widget build(BuildContext context) {
    return AdminHomePage(onLogout: _noopLogout);
  }
}
