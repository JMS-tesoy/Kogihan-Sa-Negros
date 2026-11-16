import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../../../core/widgets/app_snack_bar.dart';

import '../../data/models/agent_profile.dart';
import '../../data/models/team_request.dart';
import '../widgets/agents_tab.dart';
import '../widgets/admin_overview_tab.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final DateTime? createdAt;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id']?.toString() ?? '',
      fullName: (map['full_name'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim(),
      role: (map['role'] ?? 'user').toString().trim(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}

// ─── Supabase helpers ─────────────────────────────────────────────────────────

SupabaseClient get _db => Supabase.instance.client;

Future<List<AgentProfile>> _fetchAgentProfiles() async {
  final List<dynamic> profilesResponse = await _db
      .from('profiles')
      .select('id, full_name, email, phone, avatar_url, role')
      .eq('role', 'agent')
      .order('full_name');

  final List<String> userIds = profilesResponse
      .map(
        (item) =>
            (Map<String, dynamic>.from(item as Map)['id'] ?? '').toString(),
      )
      .where((id) => id.isNotEmpty)
      .toList();

  final List<dynamic> teamRows = await _db
      .from('team_members')
      .select('user_id, team_id, role, agent_teams(id, name)');

  final Set<String> agentProfileIds = userIds.toSet();
  final Set<String> teamAgentUserIds = <String>{};
  final Map<String, Map<String, dynamic>> teamByUserId =
      <String, Map<String, dynamic>>{};

  for (final dynamic row in teamRows) {
    final Map<String, dynamic> json = Map<String, dynamic>.from(row as Map);
    final String userId = (json['user_id'] ?? '').toString();
    if (userId.isEmpty) continue;

    final bool isAgentMember =
        (json['role'] ?? '').toString().trim().toLowerCase() == 'agent';
    if (isAgentMember) {
      teamAgentUserIds.add(userId);
    }

    final Object? team = json['agent_teams'];
    final Map<String, dynamic>? teamMap = team is Map
        ? Map<String, dynamic>.from(team)
        : null;
    if (isAgentMember || !teamByUserId.containsKey(userId)) {
      teamByUserId[userId] = {
        'id': (json['team_id'] ?? teamMap?['id'] ?? '').toString(),
        'name': (teamMap?['name'] ?? '').toString(),
      };
    }
  }

  final List<String> additionalUserIds = teamAgentUserIds
      .difference(agentProfileIds)
      .toList();
  final List<dynamic> additionalProfilesResponse = additionalUserIds.isEmpty
      ? const <dynamic>[]
      : await _db
            .from('profiles')
            .select('id, full_name, email, phone, avatar_url, role')
            .inFilter('id', additionalUserIds);

  final List<AgentProfile> profiles =
      <dynamic>[...profilesResponse, ...additionalProfilesResponse].map((item) {
        final Map<String, dynamic> json = Map<String, dynamic>.from(
          item as Map,
        );
        final String userId = (json['id'] ?? '').toString();
        final Map<String, dynamic>? team = teamByUserId[userId];

        return AgentProfile.fromMap({
          ...json,
          'agent_teams': team ?? <String, dynamic>{},
          'team_id': (team?['id'] ?? '').toString(),
        });
      }).toList();

  profiles.sort(
    (first, second) =>
        first.fullName.toLowerCase().compareTo(second.fullName.toLowerCase()),
  );
  return profiles;
}

Future<List<AppUser>> _fetchUsers() async {
  final List<dynamic> response = await _db
      .from('profiles')
      .select('id, full_name, email, role, created_at')
      .neq('role', 'admin')
      .neq('role', 'agent')
      .order('created_at', ascending: false);
  return response
      .map((item) => AppUser.fromMap(Map<String, dynamic>.from(item as Map)))
      .toList();
}

Future<List<TeamRequest>> _fetchTeamRequests() async {
  final List<dynamic> response = await _db
      .from('team_join_requests')
      .select('id, team_id, user_id, status, created_at, agent_teams(id, name)')
      .eq('status', 'pending')
      .order('created_at', ascending: false);

  if (response.isEmpty) {
    return const <TeamRequest>[];
  }

  final List<String> userIds = response
      .map(
        (item) => (Map<String, dynamic>.from(item as Map)['user_id'] ?? '')
            .toString(),
      )
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  final Map<String, Map<String, dynamic>> profilesById =
      <String, Map<String, dynamic>>{};

  if (userIds.isNotEmpty) {
    final List<dynamic> profilesResponse = await _db
        .from('profiles')
        .select('id, full_name, email')
        .inFilter('id', userIds);

    for (final dynamic row in profilesResponse) {
      final Map<String, dynamic> profile = Map<String, dynamic>.from(
        row as Map,
      );
      profilesById[profile['id']?.toString() ?? ''] = profile;
    }
  }

  return response.map((item) {
    final Map<String, dynamic> json = Map<String, dynamic>.from(item as Map);
    final String userId = (json['user_id'] ?? '').toString();
    final Object? team = json['agent_teams'];
    final Map<String, dynamic>? teamMap = team is Map
        ? Map<String, dynamic>.from(team)
        : null;
    final Map<String, dynamic> profile =
        profilesById[userId] ?? <String, dynamic>{};

    return TeamRequest.fromMap({
      ...json,
      'agent_teams': teamMap ?? <String, dynamic>{},
      'profiles': profile,
    });
  }).toList();
}

Future<void> _respondToTeamRequest({
  required String requestId,
  required String status, // 'approved' or 'rejected'
}) async {
  await _db
      .from('team_join_requests')
      .update({'status': status})
      .eq('id', requestId);
}

Future<void> _upsertProfile({
  required String id,
  required String fullName,
  required String email,
  required String phone,
  String? avatarUrl,
  String? teamId,
  String? role,
}) async {
  final Map<String, dynamic> payload = {
    'id': id,
    'full_name': fullName.trim(),
    'email': email.trim(),
    'phone': phone.trim(),
    if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
      'avatar_url': avatarUrl.trim(),
    if (teamId != null && teamId.trim().isNotEmpty) 'team_id': teamId.trim(),
    if (role != null && role.trim().isNotEmpty) 'role': role.trim(),
  };
  await _db.from('profiles').upsert(payload);
}

Future<void> _deleteProfile(String id) async {
  await _db.from('profiles').delete().eq('id', id);
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tabIndex = 0;
  int _agentCount = 0;
  int _requestCount = 0;
  int _userCount = 0;
  int? _propertyCount;
  int _agentsRefreshVersion = 0;
  int _usersRefreshVersion = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPropertyCount());
  }

  Future<void> _loadPropertyCount() async {
    try {
      final response = await _db
          .from('properties')
          .select('id')
          .count(CountOption.exact);
      if (!mounted) return;
      setState(() => _propertyCount = response.count);
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to load listing count: $error');
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.login, (route) => false);
    } catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Failed to log out. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;

    return AppScaffoldShell(
      title: 'Admin Dashboard',
      showBackButton: false,
      actions: <Widget>[
        IconButton(
          tooltip: 'Log out',
          onPressed: _signOut,
          icon: const Icon(Icons.logout_rounded),
        ),
      ],
      floatingActionButton: _tabIndex == 1
          ? FloatingActionButton.extended(
              onPressed: () {
                _showNewProfileDialog(context);
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Agent'),
            )
          : null,
      body: Column(
        children: <Widget>[
          AdminDashboardTabs(
            agentCount: _agentCount,
            requestCount: _requestCount,
            userCount: _userCount,
            selectedIndex: _tabIndex,
            onSelected: (index) => setState(() => _tabIndex = index),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        <String>[
                          'Overview',
                          'Agents',
                          'Requests',
                          'Users',
                        ][_tabIndex],
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        <String>[
                          'Platform activity and admin tasks at a glance.',
                          'Manage agent profiles and teams.',
                          'Review requests to join a team.',
                          'Browse registered user accounts.',
                        ][_tabIndex],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: <Widget>[
                AdminOverviewTab(
                  properties: _propertyCount,
                  agents: _agentCount,
                  pendingRequests: _requestCount,
                  users: _userCount,
                  onSelectTab: (index) => setState(() => _tabIndex = index),
                ),
                AgentsTab(
                  fetchProfiles: _fetchAgentProfiles,
                  upsertProfile: _upsertProfile,
                  deleteProfile: _deleteProfile,
                  refreshVersion: _agentsRefreshVersion,
                  onProfileDeleted: () {
                    setState(() => _usersRefreshVersion++);
                  },
                  onCountChanged: (count) {
                    if (mounted) setState(() => _agentCount = count);
                  },
                ),
                _RequestsTab(
                  onCountChanged: (count) {
                    if (mounted) setState(() => _requestCount = count);
                  },
                ),
                _UsersTab(
                  refreshVersion: _usersRefreshVersion,
                  onCountChanged: (count) {
                    if (mounted) setState(() => _userCount = count);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNewProfileDialog(BuildContext context) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController fullNameCtrl = TextEditingController();
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController phoneCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('New Agent Profile'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: fullNameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop();
                  try {
                    await _upsertProfile(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      fullName: fullNameCtrl.text,
                      email: emailCtrl.text,
                      phone: phoneCtrl.text,
                    );
                    if (context.mounted) {
                      AppSnackBar.success(context, 'Agent profile created.');
                      setState(() {
                        _agentsRefreshVersion++;
                        _usersRefreshVersion++;
                      });
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AppSnackBar.error(context, 'Error: $e');
                    }
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}

// ─── Custom Tab Button ───────────────────────────────────────────────────────

class AdminDashboardTabs extends StatelessWidget {
  const AdminDashboardTabs({
    super.key,
    required this.agentCount,
    required this.requestCount,
    required this.userCount,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int agentCount;
  final int requestCount;
  final int userCount;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: <Widget>[
              _TabButton(
                label: 'Overview',
                isSelected: selectedIndex == 0,
                onTap: () => onSelected(0),
              ),
              _TabButton(
                label: 'Agents',
                count: agentCount,
                isSelected: selectedIndex == 1,
                onTap: () => onSelected(1),
              ),
              _TabButton(
                label: 'Requests',
                count: requestCount,
                isSelected: selectedIndex == 2,
                onTap: () => onSelected(2),
              ),
              _TabButton(
                label: 'Users',
                count: userCount,
                isSelected: selectedIndex == 3,
                onTap: () => onSelected(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final int? tabCount = count;
    final String semanticLabel = tabCount == null ? label : '$label, $tabCount';

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: semanticLabel,
        child: Material(
          color: isSelected ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (tabCount != null) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tabCount > 99 ? '99+' : tabCount.toString(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Agents Tab ───────────────────────────────────────────────────────────────

class _RequestsTab extends StatefulWidget {
  const _RequestsTab({required this.onCountChanged});

  final ValueChanged<int> onCountChanged;

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
  List<TeamRequest> _requests = const <TeamRequest>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<TeamRequest> requests = await _fetchTeamRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
      widget.onCountChanged(requests.length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final DateTime local = dt.toLocal();
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
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  void _handleRequest(TeamRequest req, String status) async {
    try {
      await _respondToTeamRequest(requestId: req.id, status: status);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        status == 'approved' ? 'Request approved.' : 'Request rejected.',
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    if (_isLoading) {
      return const _DashboardLoadingState(label: 'Loading requests…');
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    if (_requests.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: const <Widget>[
            SizedBox(
              height: 240,
              child: _DashboardEmptyState(
                icon: Icons.inbox_outlined,
                title: 'No pending requests',
                message: 'New team requests will appear here.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final TeamRequest req = _requests[index];
          return Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: cs.tertiaryContainer,
                        child: Icon(
                          Icons.person_add_alt_outlined,
                          size: 18,
                          color: cs.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              req.requesterName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              req.requesterEmail,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.group_outlined, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            req.teamName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(req.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      OutlinedButton.icon(
                        onPressed: () => _handleRequest(req, 'rejected'),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.error,
                          side: BorderSide(color: cs.error),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => _handleRequest(req, 'approved'),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Approve'),
                      ),
                    ],
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

// ─── Users Tab ────────────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab({required this.onCountChanged, required this.refreshVersion});

  final ValueChanged<int> onCountChanged;
  final int refreshVersion;

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<AppUser> _users = const <AppUser>[];
  bool _isLoading = true;
  String? _error;
  String _search = '';
  int _loadVersion = 0;

  List<AppUser> get _filtered {
    final String q = _search.trim().toLowerCase();
    if (q.isEmpty) return _users;
    return _users.where((u) {
      return u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.role.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _UsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshVersion != widget.refreshVersion) {
      _load();
    }
  }

  Future<void> _load() async {
    final int loadVersion = ++_loadVersion;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<AppUser> users = await _fetchUsers();
      if (!mounted || loadVersion != _loadVersion) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
      widget.onCountChanged(users.length);
    } catch (e) {
      if (!mounted || loadVersion != _loadVersion) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    final DateTime local = dt.toLocal();
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
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    if (_isLoading) {
      return const _DashboardLoadingState(label: 'Loading users…');
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    final List<AppUser> filtered = _filtered;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: cs.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            onChanged: (value) => setState(() => _search = value),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: <Widget>[
                      SizedBox(
                        height: 240,
                        child: _DashboardEmptyState(
                          icon: Icons.person_search_outlined,
                          title: _search.trim().isEmpty
                              ? 'No users yet'
                              : 'No matching users',
                          message: _search.trim().isEmpty
                              ? 'Registered user accounts will appear here.'
                              : 'Try a different name, email, or role.',
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final AppUser user = filtered[index];
                      final Color roleColor = switch (user.role) {
                        'admin' => cs.error,
                        'agent' => cs.primary,
                        'moderator' => cs.tertiary,
                        _ => cs.onSurfaceVariant,
                      };

                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: roleColor.withValues(alpha: 0.14),
                            child: Icon(
                              Icons.person_outline_rounded,
                              color: roleColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            user.fullName.isEmpty ? '(no name)' : user.fullName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            user.email.isEmpty ? '—' : user.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: roleColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  user.role,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: roleColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(user.createdAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _DashboardLoadingState extends StatelessWidget {
  const _DashboardLoadingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 40, color: cs.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
