import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/agent_team_entity.dart';

class ManageAgentTeamsScreen extends StatefulWidget {
  const ManageAgentTeamsScreen({super.key});

  @override
  State<ManageAgentTeamsScreen> createState() => _ManageAgentTeamsScreenState();
}

class _ManageAgentTeamsScreenState extends State<ManageAgentTeamsScreen> {
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
            .map(
              (row) => _teamFromJson(Map<String, dynamic>.from(row as Map)),
            )
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
        content: Text(
          'This will remove ${team.name} and its team members.',
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Team deleted.')),
      );
      await _loadTeams();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete team.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Teams'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTeamForm(),
        icon: const Icon(Icons.add),
        label: const Text('New Team'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
      return const Center(child: Text('No teams yet.'));
    }

    return RefreshIndicator(
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
    );
  }
}

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
