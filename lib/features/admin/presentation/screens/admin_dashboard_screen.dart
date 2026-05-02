import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class _AgentProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String? teamId;
  final String? teamName;
  final String? role;

  const _AgentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.teamId,
    this.teamName,
    this.role,
  });

  factory _AgentProfile.fromMap(Map<String, dynamic> map) {
    final Object? team = map['agent_teams'];
    final String? teamName = team is Map
        ? (team['name']?.toString().trim().isEmpty ?? true)
              ? null
              : team['name']?.toString().trim()
        : null;
    final String? teamId = team is Map
        ? (team['id']?.toString().trim().isEmpty ?? true)
              ? null
              : team['id']?.toString().trim()
        : _toNullableString(map['team_id']);

    return _AgentProfile(
      id: map['id']?.toString() ?? '',
      fullName: (map['full_name'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim(),
      phone: (map['phone'] ?? '').toString().trim(),
      avatarUrl: _toNullableString(map['avatar_url']),
      teamId: teamId,
      teamName: teamName,
      role: _toNullableString(map['role']),
    );
  }

  static String? _toNullableString(dynamic value) {
    final String normalized = (value?.toString() ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}

class _AgentTeam {
  final String id;
  final String name;
  final int memberCount;

  const _AgentTeam({
    required this.id,
    required this.name,
    this.memberCount = 0,
  });

  factory _AgentTeam.fromMap(Map<String, dynamic> map) {
    return _AgentTeam(
      id: map['id']?.toString() ?? '',
      name: (map['name'] ?? '').toString().trim(),
      memberCount: _toInt(map['member_count']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _AppUser {
  final String id;
  final String fullName;
  final String email;
  final String role;
  final DateTime? createdAt;

  const _AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory _AppUser.fromMap(Map<String, dynamic> map) {
    return _AppUser(
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

class _TeamRequest {
  final String id;
  final String userId;
  final String teamId;
  final String teamName;
  final String requesterName;
  final String requesterEmail;
  final String status;
  final DateTime? createdAt;

  const _TeamRequest({
    required this.id,
    required this.userId,
    required this.teamId,
    required this.teamName,
    required this.requesterName,
    required this.requesterEmail,
    required this.status,
    this.createdAt,
  });

  factory _TeamRequest.fromMap(Map<String, dynamic> map) {
    final Object? team = map['agent_teams'];
    final Object? profile = map['profiles'];

    return _TeamRequest(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      teamId: map['team_id']?.toString() ?? '',
      teamName: team is Map
          ? (team['name']?.toString().trim() ?? 'Unknown Team')
          : 'Unknown Team',
      requesterName: profile is Map
          ? (profile['full_name']?.toString().trim() ?? 'Unknown')
          : 'Unknown',
      requesterEmail: profile is Map
          ? (profile['email']?.toString().trim() ?? '')
          : '',
      status: (map['status'] ?? 'pending').toString().trim(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}

// ─── Supabase helpers ─────────────────────────────────────────────────────────

SupabaseClient get _db => Supabase.instance.client;

Future<List<_AgentProfile>> _fetchAgentProfiles() async {
  final List<dynamic> response = await _db
      .from('profiles')
      .select('*, agent_teams(id, name)')
      .order('full_name');
  return response
      .map(
        (item) => _AgentProfile.fromMap(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
}

Future<List<_AgentTeam>> _fetchTeams() async {
  final List<dynamic> response = await _db
      .from('agent_teams')
      .select('*')
      .order('name');
  return response
      .map((item) => _AgentTeam.fromMap(Map<String, dynamic>.from(item as Map)))
      .toList();
}

Future<List<_AppUser>> _fetchUsers() async {
  final List<dynamic> response = await _db
      .from('profiles')
      .select('id, full_name, email, role, created_at')
      .order('created_at', ascending: false);
  return response
      .map((item) => _AppUser.fromMap(Map<String, dynamic>.from(item as Map)))
      .toList();
}

Future<List<_TeamRequest>> _fetchTeamRequests() async {
  final List<dynamic> response = await _db
      .from('team_requests')
      .select('*, agent_teams(id, name), profiles(full_name, email)')
      .eq('status', 'pending')
      .order('created_at', ascending: false);
  return response
      .map(
        (item) => _TeamRequest.fromMap(Map<String, dynamic>.from(item as Map)),
      )
      .toList();
}

Future<void> _respondToTeamRequest({
  required String requestId,
  required String status, // 'approved' or 'rejected'
}) async {
  await _db
      .from('team_requests')
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

Future<void> _upsertTeam({String? id, required String name}) async {
  final Map<String, dynamic> payload = {'name': name.trim()};
  if (id != null && id.trim().isNotEmpty) {
    await _db.from('agent_teams').update(payload).eq('id', id);
  } else {
    await _db.from('agent_teams').insert(payload);
  }
}

Future<void> _deleteTeam(String id) async {
  await _db.from('agent_teams').delete().eq('id', id);
}

Future<Map<String, int>> _fetchDashboardStats() async {
  final List<dynamic> profiles = await _db.from('profiles').select('id, role');
  final List<dynamic> teams = await _db.from('agent_teams').select('id');
  final List<dynamic> properties = await _db.from('properties').select('id');

  final int agentCount = profiles
      .where((p) => (p['role']?.toString() ?? '') == 'agent')
      .length;

  return {
    'total_profiles': profiles.length,
    'agents': agentCount,
    'teams': teams.length,
    'properties': properties.length,
  };
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: AppScaffoldShell(
        title: 'Admin Dashboard',
        body: Column(
          children: <Widget>[
            const TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Widget>[
                Tab(icon: Icon(Icons.dashboard_rounded), text: 'Overview'),
                Tab(icon: Icon(Icons.person_rounded), text: 'Agents'),
                Tab(icon: Icon(Icons.groups_rounded), text: 'Teams'),
                Tab(icon: Icon(Icons.people_alt_rounded), text: 'Users'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: <Widget>[
                  _OverviewTab(),
                  _AgentsTab(),
                  _TeamsTab(),
                  _UsersTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  Map<String, int>? _stats;
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
      final Map<String, int> stats = await _fetchDashboardStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    final Map<String, int> stats = _stats!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            'Platform Overview',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Live snapshot of your app data.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: <Widget>[
              _StatCard(
                label: 'Total Profiles',
                value: '${stats['total_profiles'] ?? 0}',
                icon: Icons.person_outline_rounded,
                color: cs.primary,
              ),
              _StatCard(
                label: 'Agents',
                value: '${stats['agents'] ?? 0}',
                icon: Icons.badge_outlined,
                color: Colors.orange,
              ),
              _StatCard(
                label: 'Teams',
                value: '${stats['teams'] ?? 0}',
                icon: Icons.groups_outlined,
                color: Colors.teal,
              ),
              _StatCard(
                label: 'Listings',
                value: '${stats['properties'] ?? 0}',
                icon: Icons.home_work_outlined,
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader(
            title: 'Quick Actions',
            subtitle: 'Common admin operations.',
          ),
          const SizedBox(height: 12),
          _QuickActionTile(
            icon: Icons.person_add_rounded,
            label: 'Add Agent Profile',
            color: cs.primary,
            onTap: () => _openAgentForm(context),
          ),
          const SizedBox(height: 10),
          _QuickActionTile(
            icon: Icons.group_add_rounded,
            label: 'Add Team',
            color: Colors.teal,
            onTap: () => _openTeamForm(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openAgentForm(BuildContext context) async {
    final List<_AgentTeam> teams = await _fetchTeams();
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AgentFormSheet(teams: teams, profile: null),
    );
    _load();
  }

  Future<void> _openTeamForm(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _TeamFormSheet(team: null),
    );
    _load();
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

// ─── Agents Tab ───────────────────────────────────────────────────────────────

class _AgentsTab extends StatefulWidget {
  const _AgentsTab();

  @override
  State<_AgentsTab> createState() => _AgentsTabState();
}

class _AgentsTabState extends State<_AgentsTab> {
  List<_AgentProfile> _profiles = const <_AgentProfile>[];
  List<_AgentTeam> _teams = const <_AgentTeam>[];
  bool _isLoading = true;
  String? _error;
  String _search = '';

  List<_AgentProfile> get _filtered {
    final String q = _search.trim().toLowerCase();
    if (q.isEmpty) return _profiles;
    return _profiles.where((p) {
      return p.fullName.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q) ||
          p.phone.toLowerCase().contains(q);
    }).toList();
  }

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
      final List<_AgentProfile> profiles = await _fetchAgentProfiles();
      final List<_AgentTeam> teams = await _fetchTeams();
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
        _teams = teams;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openForm({_AgentProfile? profile}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AgentFormSheet(teams: _teams, profile: profile),
    );
    _load();
  }

  Future<void> _confirmDelete(_AgentProfile profile) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Agent'),
        content: Text(
          'Remove "${profile.fullName}" from profiles? This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _deleteProfile(profile.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${profile.fullName} removed.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    final List<_AgentProfile> filtered = _filtered;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search agents...',
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
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                _search.isEmpty ? 'No agent profiles yet.' : 'No results.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final _AgentProfile profile = filtered[index];
                  return _AgentProfileCard(
                    profile: profile,
                    onEdit: () => _openForm(profile: profile),
                    onDelete: () => _confirmDelete(profile),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _AgentProfileCard extends StatelessWidget {
  final _AgentProfile profile;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AgentProfileCard({
    required this.profile,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Avatar
            CircleAvatar(
              radius: 26,
              backgroundColor: cs.primaryContainer,
              backgroundImage:
                  profile.avatarUrl != null &&
                      profile.avatarUrl!.startsWith('http')
                  ? NetworkImage(profile.avatarUrl!)
                  : null,
              child:
                  profile.avatarUrl == null ||
                      !profile.avatarUrl!.startsWith('http')
                  ? Icon(
                      Icons.person_outline_rounded,
                      color: cs.primary,
                      size: 28,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          profile.fullName.isEmpty
                              ? 'No name set'
                              : profile.fullName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if ((profile.role ?? '').isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cs.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            profile.role!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: cs.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _ContactLine(
                    icon: Icons.mail_outline_rounded,
                    value: profile.email.isEmpty ? '— no email' : profile.email,
                    cs: cs,
                    textTheme: theme.textTheme,
                  ),
                  _ContactLine(
                    icon: Icons.call_outlined,
                    value: profile.phone.isEmpty ? '— no phone' : profile.phone,
                    cs: cs,
                    textTheme: theme.textTheme,
                    highlight: profile.phone.isEmpty,
                  ),
                  if (profile.teamName != null)
                    _ContactLine(
                      icon: Icons.groups_outlined,
                      value: profile.teamName!,
                      cs: cs,
                      textTheme: theme.textTheme,
                    ),
                ],
              ),
            ),
            // Actions
            Column(
              children: <Widget>[
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_rounded),
                  tooltip: 'Edit',
                  iconSize: 20,
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  tooltip: 'Delete',
                  iconSize: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String value;
  final ColorScheme cs;
  final TextTheme textTheme;
  final bool highlight;

  const _ContactLine({
    required this.icon,
    required this.value,
    required this.cs,
    required this.textTheme,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodySmall?.copyWith(
                color: highlight ? cs.error : cs.onSurfaceVariant,
                fontStyle: highlight ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentFormSheet extends StatefulWidget {
  final List<_AgentTeam> teams;
  final _AgentProfile? profile;

  const _AgentFormSheet({required this.teams, required this.profile});

  @override
  State<_AgentFormSheet> createState() => _AgentFormSheetState();
}

class _AgentFormSheetState extends State<_AgentFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _avatarUrlController;

  String? _selectedTeamId;
  String _selectedRole = 'agent';
  bool _isSaving = false;

  static const List<String> _roles = <String>['agent', 'admin', 'moderator'];

  bool get _isEditing => widget.profile != null;

  @override
  void initState() {
    super.initState();
    final _AgentProfile? profile = widget.profile;
    _nameController = TextEditingController(text: profile?.fullName ?? '');
    _emailController = TextEditingController(text: profile?.email ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    _avatarUrlController = TextEditingController(
      text: profile?.avatarUrl ?? '',
    );
    _selectedTeamId = profile?.teamId;
    _selectedRole = profile?.role ?? 'agent';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _upsertProfile(
        id: widget.profile?.id ?? _db.auth.currentUser!.id,
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim().isNotEmpty
            ? _avatarUrlController.text.trim()
            : null,
        teamId: _selectedTeamId,
        role: _selectedRole,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Profile updated.' : 'Profile created.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                _isEditing ? 'Edit Agent' : 'New Agent',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),

              const _FormLabel(text: 'Full Name'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: _inputDecoration(
                  hint: 'e.g. Joh Sah',
                  icon: Icons.person_outline_rounded,
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              const _FormLabel(text: 'Email'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                  hint: 'agent@example.com',
                  icon: Icons.mail_outline_rounded,
                ),
                validator: (value) =>
                    (value ?? '').trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              const _FormLabel(text: 'Phone Number'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s()]')),
                ],
                decoration: _inputDecoration(
                  hint: '+63 917 123 4567',
                  icon: Icons.call_outlined,
                ),
              ),
              const SizedBox(height: 14),

              const _FormLabel(text: 'Avatar URL (optional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _avatarUrlController,
                keyboardType: TextInputType.url,
                decoration: _inputDecoration(
                  hint: 'https://...',
                  icon: Icons.image_outlined,
                ),
              ),
              const SizedBox(height: 14),

              const _FormLabel(text: 'Team (optional)'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String?>(
                initialValue: _selectedTeamId,
                decoration: _inputDecoration(
                  hint: 'No team assigned',
                  icon: Icons.groups_outlined,
                ),
                items: <DropdownMenuItem<String?>>[
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('— None —'),
                  ),
                  ...widget.teams.map(
                    (team) => DropdownMenuItem<String?>(
                      value: team.id,
                      child: Text(team.name),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedTeamId = value),
              ),
              const SizedBox(height: 14),

              const _FormLabel(text: 'Role'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: _inputDecoration(
                  hint: 'Select role',
                  icon: Icons.badge_outlined,
                ),
                items: _roles
                    .map(
                      (role) => DropdownMenuItem<String>(
                        value: role,
                        child: Text(role),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _selectedRole = value ?? 'agent'),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(_isEditing ? 'Save Changes' : 'Create Profile'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;

  const _FormLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

// ─── Teams Tab (Manage Teams) ─────────────────────────────────────────────────
// Contains two sub-tabs: Agent Teams & Team Requests

class _TeamsTab extends StatefulWidget {
  const _TeamsTab();

  @override
  State<_TeamsTab> createState() => _TeamsTabState();
}

class _TeamsTabState extends State<_TeamsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Sub-tab header
        Container(
          color: cs.surface,
          child: TabBar(
            controller: _subTabController,
            labelColor: cs.primary,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicatorColor: cs.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: cs.outlineVariant,
            tabs: const <Widget>[
              Tab(
                icon: Icon(Icons.groups_rounded),
                text: 'Agent Teams',
                iconMargin: EdgeInsets.only(bottom: 2),
              ),
              Tab(
                icon: Icon(Icons.person_search_rounded),
                text: 'Team Requests',
                iconMargin: EdgeInsets.only(bottom: 2),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: const <Widget>[
              _AgentTeamsSection(),
              _TeamRequestsSection(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Agent Teams Section ──────────────────────────────────────────────────────

class _AgentTeamsSection extends StatefulWidget {
  const _AgentTeamsSection();

  @override
  State<_AgentTeamsSection> createState() => _AgentTeamsSectionState();
}

class _AgentTeamsSectionState extends State<_AgentTeamsSection> {
  List<_AgentTeam> _teams = const <_AgentTeam>[];
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
      final List<_AgentTeam> teams = await _fetchTeams();
      if (!mounted) return;
      setState(() {
        _teams = teams;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openForm({_AgentTeam? team}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TeamFormSheet(team: team),
    );
    _load();
  }

  Future<void> _confirmDelete(_AgentTeam team) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Team'),
        content: Text('Remove "${team.name}"? This cannot be undone.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _deleteTeam(team.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${team.name}" removed.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${_teams.length} team(s)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Team'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_teams.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No teams yet. Add your first team.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _teams.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final _AgentTeam team = _teams[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: Colors.teal,
                        ),
                      ),
                      title: Text(
                        team.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text('ID: ${team.id}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.edit_rounded),
                            onPressed: () => _openForm(team: team),
                            iconSize: 20,
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: theme.colorScheme.error,
                            ),
                            onPressed: () => _confirmDelete(team),
                            iconSize: 20,
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

// ─── Team Requests Section ────────────────────────────────────────────────────

class _TeamRequestsSection extends StatefulWidget {
  const _TeamRequestsSection();

  @override
  State<_TeamRequestsSection> createState() => _TeamRequestsSectionState();
}

class _TeamRequestsSectionState extends State<_TeamRequestsSection> {
  List<_TeamRequest> _requests = const <_TeamRequest>[];
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
      final List<_TeamRequest> requests = await _fetchTeamRequests();
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _respond({
    required _TeamRequest request,
    required bool approve,
  }) async {
    final String status = approve ? 'approved' : 'rejected';
    try {
      await _respondToTeamRequest(requestId: request.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? '${request.requesterName} approved to join ${request.teamName}.'
                : 'Request from ${request.requesterName} rejected.',
          ),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  Future<void> _confirmRespond({
    required _TeamRequest request,
    required bool approve,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve Request' : 'Reject Request'),
        content: Text(
          approve
              ? 'Allow ${request.requesterName} to join "${request.teamName}"?'
              : 'Reject ${request.requesterName}\'s request to join "${request.teamName}"?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: approve
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _respond(request: request, approve: approve);
  }

  String _timeAgo(DateTime? dt) {
    if (dt == null) return '';
    final Duration diff = DateTime.now().difference(dt.toLocal());
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _requests.isEmpty
                      ? 'No pending requests'
                      : '${_requests.length} pending request(s)',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        if (_requests.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 48,
                    color: Colors.teal.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'All caught up!',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'No pending join requests at this time.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: _requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final _TeamRequest req = _requests[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: cs.primaryContainer,
                                child: Icon(
                                  Icons.person_outline_rounded,
                                  color: cs.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      req.requesterName.isEmpty
                                          ? 'Unknown'
                                          : req.requesterName,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (req.requesterEmail.isNotEmpty)
                                      Text(
                                        req.requesterEmail,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: cs.onSurfaceVariant,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              Text(
                                _timeAgo(req.createdAt),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: <Widget>[
                              Icon(
                                Icons.groups_rounded,
                                size: 14,
                                color: Colors.teal,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Requesting to join ',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  req.teamName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _confirmRespond(
                                    request: req,
                                    approve: false,
                                  ),
                                  icon: Icon(
                                    Icons.close_rounded,
                                    color: cs.error,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Reject',
                                    style: TextStyle(color: cs.error),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: cs.error.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => _confirmRespond(
                                    request: req,
                                    approve: true,
                                  ),
                                  icon: const Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Approve'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
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

// ─── Team Form Sheet ──────────────────────────────────────────────────────────

class _TeamFormSheet extends StatefulWidget {
  final _AgentTeam? team;

  const _TeamFormSheet({required this.team});

  @override
  State<_TeamFormSheet> createState() => _TeamFormSheetState();
}

class _TeamFormSheetState extends State<_TeamFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _isSaving = false;

  bool get _isEditing => widget.team != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.team?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await _upsertTeam(id: widget.team?.id, name: _nameController.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Team updated.' : 'Team created.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _isEditing ? 'Edit Team' : 'New Team',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
            const _FormLabel(text: 'Team Name'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. KSN Verified Agents',
                prefixIcon: const Icon(Icons.groups_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_isEditing ? 'Save Changes' : 'Create Team'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Users Tab ────────────────────────────────────────────────────────────────

class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  List<_AppUser> _users = const <_AppUser>[];
  bool _isLoading = true;
  String? _error;
  String _search = '';

  List<_AppUser> get _filtered {
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

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<_AppUser> users = await _fetchUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
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

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(message: _error!, onRetry: _load);
    }

    final List<_AppUser> filtered = _filtered;

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
        if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                _search.isEmpty ? 'No users found.' : 'No results.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final _AppUser user = filtered[index];
                  final Color roleColor = switch (user.role) {
                    'admin' => cs.error,
                    'agent' => cs.primary,
                    'moderator' => Colors.orange,
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

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
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
