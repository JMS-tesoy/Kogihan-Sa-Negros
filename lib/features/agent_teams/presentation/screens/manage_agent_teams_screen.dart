import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/agent_team_entity.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class _TeamRequest {
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

  factory _TeamRequest.fromJson(Map<String, dynamic> json) {
    final Object? team = json['agent_teams'];
    final Object? profile = json['profiles'];
    return _TeamRequest(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      teamId: json['team_id'] as String? ?? '',
      teamName: team is Map
          ? (team['name']?.toString().trim() ?? 'Unknown Team')
          : 'Unknown Team',
      requesterName: profile is Map
          ? (profile['full_name']?.toString().trim() ?? 'Unknown')
          : 'Unknown',
      requesterEmail: profile is Map
          ? (profile['email']?.toString().trim() ?? '')
          : '',
      status: (json['status'] ?? 'pending').toString().trim(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  final String id;
  final String userId;
  final String teamId;
  final String teamName;
  final String requesterName;
  final String requesterEmail;
  final String status;
  final DateTime? createdAt;
}

// ─── Main Screen ──────────────────────────────────────────────────────────────

class ManageAgentTeamsScreen extends StatefulWidget {
  const ManageAgentTeamsScreen({super.key});

  @override
  State<ManageAgentTeamsScreen> createState() => _ManageAgentTeamsScreenState();
}

class _ManageAgentTeamsScreenState extends State<ManageAgentTeamsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Teams'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: cs.primary,
          tabs: const <Widget>[
            Tab(icon: Icon(Icons.groups_rounded), text: 'Agent Teams'),
            Tab(icon: Icon(Icons.person_search_rounded), text: 'Team Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const <Widget>[_AgentTeamsTab(), _TeamRequestsTab()],
      ),
    );
  }
}

// ─── Agent Teams Tab ──────────────────────────────────────────────────────────

class _AgentTeamsTab extends StatefulWidget {
  const _AgentTeamsTab();

  @override
  State<_AgentTeamsTab> createState() => _AgentTeamsTabState();
}

class _AgentTeamsTabState extends State<_AgentTeamsTab> {
  final SupabaseClient _client = Supabase.instance.client;
  List<AgentTeamEntity> _teams = const <AgentTeamEntity>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTeams();
  }

  Future<void> _loadTeams() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<dynamic> rows = await _client
          .from('agent_teams')
          .select('id, name, description, logo_url, specialization')
          .order('name');
      if (!mounted) return;
      setState(() {
        _teams = rows
            .map((row) => _teamFromJson(Map<String, dynamic>.from(row as Map)))
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load agent teams.';
        _isLoading = false;
      });
    }
  }

  AgentTeamEntity _teamFromJson(Map<String, dynamic> json) {
    return AgentTeamEntity(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      specialization: json['specialization'] as String? ?? '',
    );
  }

  Future<void> _openTeamForm({AgentTeamEntity? team}) async {
    final _TeamFormResult? result = await showDialog<_TeamFormResult>(
      context: context,
      builder: (context) => _TeamFormDialog(team: team),
    );
    if (result == null) return;

    try {
      final Map<String, dynamic> values = {
        'name': result.name,
        'description': result.description,
        'specialization': result.specialization,
        'logo_url': result.logoUrl.isEmpty ? null : result.logoUrl,
      };
      if (team == null) {
        await _client.from('agent_teams').insert(values);
      } else {
        await _client.from('agent_teams').update(values).eq('id', team.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(team == null ? 'Team created.' : 'Team updated.'),
        ),
      );
      await _loadTeams();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            team == null ? 'Failed to create team.' : 'Failed to update team.',
          ),
        ),
      );
    }
  }

  Future<void> _deleteTeam(AgentTeamEntity team) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete team?'),
        content: Text('This will remove ${team.name} and its team members.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await _client.from('agent_teams').delete().eq('id', team.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Team deleted.')));
      await _loadTeams();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete team.')));
    }
  }

  Future<void> _openMembersDialog(AgentTeamEntity team) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _TeamMembersDialog(team: team),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadTeams,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_teams.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('No teams yet.'),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openTeamForm(),
              icon: const Icon(Icons.add),
              label: const Text('New Team'),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: <Widget>[
        RefreshIndicator(
          onRefresh: _loadTeams,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: _teams.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final AgentTeamEntity team = _teams[index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(team.name),
                  subtitle: Text(
                    team.specialization.isEmpty
                        ? 'No specialization'
                        : team.specialization,
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Members',
                        icon: const Icon(Icons.groups_outlined),
                        onPressed: () => _openMembersDialog(team),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _openTeamForm(team: team),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTeam(team),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'add_team_fab',
            onPressed: () => _openTeamForm(),
            icon: const Icon(Icons.add),
            label: const Text('New Team'),
          ),
        ),
      ],
    );
  }
}

// ─── Team Requests Tab ────────────────────────────────────────────────────────

class _TeamRequestsTab extends StatefulWidget {
  const _TeamRequestsTab();

  @override
  State<_TeamRequestsTab> createState() => _TeamRequestsTabState();
}

class _TeamRequestsTabState extends State<_TeamRequestsTab> {
  final SupabaseClient _client = Supabase.instance.client;
  List<_TeamRequest> _requests = const <_TeamRequest>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<dynamic> rows = await _client
          .from('team_requests')
          .select('*, agent_teams(id, name), profiles(full_name, email)')
          .eq('status', 'pending')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _requests = rows
            .map(
              (row) =>
                  _TeamRequest.fromJson(Map<String, dynamic>.from(row as Map)),
            )
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load team requests.';
        _isLoading = false;
      });
    }
  }

  Future<void> _respond({
    required _TeamRequest request,
    required bool approve,
  }) async {
    try {
      await _client
          .from('team_requests')
          .update({'status': approve ? 'approved' : 'rejected'})
          .eq('id', request.id);
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
      await _loadRequests();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Action failed.')));
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadRequests,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.check_circle_outline_rounded,
              size: 52,
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
              'No pending join requests.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _requests.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
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
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (req.requesterEmail.isNotEmpty)
                              Text(
                                req.requesterEmail,
                                style: theme.textTheme.bodySmall?.copyWith(
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
                      const Icon(
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
                          onPressed: () =>
                              _confirmRespond(request: req, approve: false),
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
                          onPressed: () =>
                              _confirmRespond(request: req, approve: true),
                          icon: const Icon(Icons.check_rounded, size: 18),
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
    );
  }
}

// ─── Team Form Dialog ─────────────────────────────────────────────────────────

class _TeamFormDialog extends StatefulWidget {
  const _TeamFormDialog({this.team});

  final AgentTeamEntity? team;

  @override
  State<_TeamFormDialog> createState() => _TeamFormDialogState();
}

class _TeamFormDialogState extends State<_TeamFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _specializationController;
  late final TextEditingController _logoUrlController;

  @override
  void initState() {
    super.initState();
    final AgentTeamEntity? team = widget.team;
    _nameController = TextEditingController(text: team?.name ?? '');
    _descriptionController = TextEditingController(
      text: team?.description ?? '',
    );
    _specializationController = TextEditingController(
      text: team?.specialization ?? '',
    );
    _logoUrlController = TextEditingController(text: team?.logoUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _specializationController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _TeamFormResult(
        name: name,
        description: _descriptionController.text.trim(),
        specialization: _specializationController.text.trim(),
        logoUrl: _logoUrlController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.team != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Team' : 'Create Team'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Team name'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _specializationController,
              decoration: const InputDecoration(labelText: 'Specialization'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              minLines: 2,
              maxLines: 4,
            ),
            TextField(
              controller: _logoUrlController,
              decoration: const InputDecoration(labelText: 'Logo URL'),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _TeamFormResult {
  const _TeamFormResult({
    required this.name,
    required this.description,
    required this.specialization,
    required this.logoUrl,
  });

  final String name;
  final String description;
  final String specialization;
  final String logoUrl;
}

// ─── Team Members Dialog ──────────────────────────────────────────────────────

class _TeamMembersDialog extends StatefulWidget {
  const _TeamMembersDialog({required this.team});

  final AgentTeamEntity team;

  @override
  State<_TeamMembersDialog> createState() => _TeamMembersDialogState();
}

class _TeamMembersDialogState extends State<_TeamMembersDialog> {
  final SupabaseClient _client = Supabase.instance.client;
  List<_EditableTeamMember> _members = const <_EditableTeamMember>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<dynamic> rows = await _client
          .from('team_members')
          .select('id, user_id, name, role, avatar_url, phone, email')
          .eq('team_id', widget.team.id)
          .order('name');
      if (!mounted) return;
      setState(() {
        _members = rows
            .map(
              (row) => _EditableTeamMember.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load members.';
        _isLoading = false;
      });
    }
  }

  Future<void> _openMemberForm({_EditableTeamMember? member}) async {
    final _MemberFormResult? result = await showDialog<_MemberFormResult>(
      context: context,
      builder: (context) => _MemberFormDialog(member: member),
    );
    if (result == null) return;

    try {
      final Map<String, dynamic> values = {
        'name': result.name,
        'role': result.role.trim().isEmpty ? 'Member' : result.role.trim(),
        'avatar_url': result.avatarUrl.trim().isEmpty
            ? null
            : result.avatarUrl.trim(),
        'phone': result.phone.trim().isEmpty ? null : result.phone.trim(),
        'email': result.email.trim().isEmpty ? null : result.email.trim(),
      };
      final String userId = result.userId.trim();
      if (userId.isNotEmpty) {
        values['user_id'] = userId;
      }
      if (member == null) {
        await _client.from('team_members').insert({
          ...values,
          'team_id': widget.team.id,
        });
      } else {
        await _client.from('team_members').update(values).eq('id', member.id);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(member == null ? 'Member added.' : 'Member updated.'),
        ),
      );
      await _loadMembers();
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            member == null
                ? 'Failed to add member: ${error.message}'
                : 'Failed to update member: ${error.message}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            member == null
                ? 'Failed to add member: $error'
                : 'Failed to update member: $error',
          ),
        ),
      );
    }
  }

  Future<void> _deleteMember(_EditableTeamMember member) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('This will remove ${member.name} from this team.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;

    try {
      await _client.from('team_members').delete().eq('id', member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Member removed.')));
      await _loadMembers();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to remove member.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.team.name} Members'),
      content: SizedBox(width: double.maxFinite, child: _buildContent()),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => _openMemberForm(),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Add Member'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loadMembers,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_members.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No members yet.')),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _members.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final _EditableTeamMember member = _members[index];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(member.name),
            subtitle: Text(
              member.userId == null || member.userId!.isEmpty
                  ? (member.role.isEmpty ? 'No role' : member.role)
                  : '${member.role.isEmpty ? 'No role' : member.role} - Linked profile',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _openMemberForm(member: member),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _deleteMember(member),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Member Form Dialog ───────────────────────────────────────────────────────

class _MemberFormDialog extends StatefulWidget {
  const _MemberFormDialog({this.member});

  final _EditableTeamMember? member;

  @override
  State<_MemberFormDialog> createState() => _MemberFormDialogState();
}

class _MemberFormDialogState extends State<_MemberFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _userIdController;
  late final TextEditingController _roleController;
  late final TextEditingController _avatarUrlController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    final _EditableTeamMember? member = widget.member;
    _nameController = TextEditingController(text: member?.name ?? '');
    _userIdController = TextEditingController(text: member?.userId ?? '');
    _roleController = TextEditingController(text: member?.role ?? '');
    _avatarUrlController = TextEditingController(text: member?.avatarUrl ?? '');
    _phoneController = TextEditingController(text: member?.phone ?? '');
    _emailController = TextEditingController(text: member?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _userIdController.dispose();
    _roleController.dispose();
    _avatarUrlController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      _MemberFormResult(
        name: name,
        userId: _userIdController.text.trim(),
        role: _roleController.text.trim(),
        avatarUrl: _avatarUrlController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.member != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Member' : 'Add Member'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _roleController,
              decoration: const InputDecoration(labelText: 'Role'),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _userIdController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                helperText: 'Optional. Links this member to an app account.',
              ),
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            TextField(
              controller: _avatarUrlController,
              decoration: const InputDecoration(labelText: 'Avatar URL'),
              keyboardType: TextInputType.url,
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isEditing ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}

// ─── Data Classes ─────────────────────────────────────────────────────────────

class _EditableTeamMember {
  const _EditableTeamMember({
    required this.id,
    required this.name,
    required this.userId,
    required this.role,
    required this.avatarUrl,
    required this.phone,
    required this.email,
  });

  factory _EditableTeamMember.fromJson(Map<String, dynamic> json) {
    return _EditableTeamMember(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      userId: json['user_id'] as String?,
      role: json['role'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }

  final String id;
  final String name;
  final String? userId;
  final String role;
  final String? avatarUrl;
  final String? phone;
  final String? email;
}

class _MemberFormResult {
  const _MemberFormResult({
    required this.name,
    required this.userId,
    required this.role,
    required this.avatarUrl,
    required this.phone,
    required this.email,
  });

  final String name;
  final String userId;
  final String role;
  final String avatarUrl;
  final String phone;
  final String email;
}
