import 'dart:async';

import 'package:flutter/material.dart';
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

    Map<String, dynamic>? teamMap;
    if (team is Map) {
      teamMap = Map<String, dynamic>.from(team);
    } else if (team is List && team.isNotEmpty) {
      teamMap = Map<String, dynamic>.from(team.first);
    }

    Map<String, dynamic>? profileMap;
    if (profile is Map) {
      profileMap = Map<String, dynamic>.from(profile);
    } else if (profile is List && profile.isNotEmpty) {
      profileMap = Map<String, dynamic>.from(profile.first);
    }

    return _TeamRequest(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      teamId: map['team_id']?.toString() ?? '',
      teamName: teamMap?['name']?.toString().trim() ?? 'Unknown Team',
      requesterName: profileMap?['full_name']?.toString().trim() ?? 'Unknown',
      requesterEmail: profileMap?['email']?.toString().trim() ?? '',
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

// ─── Main Screen ─────────────────────────────────────────────────────────────

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return AppScaffoldShell(
      title: 'Admin Dashboard',
      showBackButton: true,
      floatingActionButton: _tabIndex == 0
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            child: Row(
              children: <Widget>[
                _TabButton(
                  label: 'Agents',
                  isSelected: _tabIndex == 0,
                  onTap: () => setState(() => _tabIndex = 0),
                ),
                _TabButton(
                  label: 'Requests',
                  isSelected: _tabIndex == 1,
                  onTap: () => setState(() => _tabIndex = 1),
                ),
                _TabButton(
                  label: 'Users',
                  isSelected: _tabIndex == 2,
                  onTap: () => setState(() => _tabIndex = 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tabIndex,
              children: const <Widget>[
                _AgentsTab(),
                _RequestsTab(),
                _UsersTab(),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Agent profile created.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? cs.primary : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
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
  bool _isLoading = true;
  String? _error;
  String _search = '';

  List<_AgentProfile> get _filtered {
    final String q = _search.trim().toLowerCase();
    if (q.isEmpty) return _profiles;
    return _profiles.where((p) {
      return p.fullName.toLowerCase().contains(q) ||
          p.email.toLowerCase().contains(q) ||
          (p.teamName?.toLowerCase().contains(q) ?? false) ||
          (p.phone.toLowerCase().contains(q));
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
      if (!mounted) return;
      setState(() {
        _profiles = profiles;
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

  void _showEditDialog(_AgentProfile profile) {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController fullNameCtrl = TextEditingController(
      text: profile.fullName,
    );
    final TextEditingController emailCtrl = TextEditingController(
      text: profile.email,
    );
    final TextEditingController phoneCtrl = TextEditingController(
      text: profile.phone,
    );
    final TextEditingController avatarCtrl = TextEditingController(
      text: profile.avatarUrl ?? '',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Agent'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: avatarCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Avatar URL (opt)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final bool? confirm = await showDialog<bool>(
                  context: ctx,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Agent?'),
                    content: const Text('This action cannot be undone.'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirm ?? false) {
                  if (!ctx.mounted) return;
                  Navigator.of(ctx).pop();
                  try {
                    await _deleteProfile(profile.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Agent deleted.')),
                      );
                      _load();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              child: const Text('Delete'),
            ),
            FilledButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop();
                  try {
                    await _upsertProfile(
                      id: profile.id,
                      fullName: fullNameCtrl.text,
                      email: emailCtrl.text,
                      phone: phoneCtrl.text,
                      avatarUrl: avatarCtrl.text.trim().isEmpty
                          ? null
                          : avatarCtrl.text.trim(),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Agent updated.')),
                      );
                      _load();
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
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
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                _search.isEmpty ? 'No agents found.' : 'No results.',
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
                  final _AgentProfile profile = filtered[index];
                  return Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      onTap: () => _showEditDialog(profile),
                      leading: CircleAvatar(
                        backgroundColor: cs.primaryContainer,
                        backgroundImage:
                            profile.avatarUrl != null &&
                                profile.avatarUrl!.isNotEmpty
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child:
                            profile.avatarUrl == null ||
                                profile.avatarUrl!.isEmpty
                            ? Icon(
                                Icons.person_outline_rounded,
                                color: cs.onPrimaryContainer,
                              )
                            : null,
                      ),
                      title: Text(
                        profile.fullName.isEmpty
                            ? '(no name)'
                            : profile.fullName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            profile.email.isEmpty ? '—' : profile.email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (profile.teamName != null &&
                              profile.teamName!.isNotEmpty)
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.group_outlined,
                                  size: 13,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  profile.teamName!,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 20),
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

// ─── Requests Tab ─────────────────────────────────────────────────────────────

class _RequestsTab extends StatefulWidget {
  const _RequestsTab();

  @override
  State<_RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<_RequestsTab> {
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

  void _handleRequest(_TeamRequest req, String status) async {
    try {
      await _respondToTeamRequest(requestId: req.id, status: status);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Request approved.' : 'Request rejected.',
          ),
        ),
      );
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
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

    if (_requests.isEmpty) {
      return Center(
        child: Text(
          'No pending requests.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
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
