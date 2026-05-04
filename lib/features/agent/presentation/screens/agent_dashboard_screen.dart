import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/router/route_names.dart';
import '../models/agent_inquiry.dart';
import 'agent_inbox_page.dart';
import '../../../agent_teams/presentation/screens/manage_agent_teams_screen.dart';
import '../../../agent_teams/presentation/screens/team_inbox_screen.dart';
import '../../../messaging/data/services/messaging_service.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import 'manage_properties_page.dart';
import 'property_form_page.dart';

Route<T> _instantRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
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
    final List<AgentInquiry> cachedInquiries = cachedAgentInquiries();
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

class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({super.key});

  static Future<void> _noopLogout(BuildContext context) async {}

  @override
  Widget build(BuildContext context) {
    return AdminHomePage(onLogout: _noopLogout);
  }
}
