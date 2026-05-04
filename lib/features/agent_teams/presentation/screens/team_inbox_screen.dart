import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/team_chat_team.dart';
import 'team_conversation_screen.dart';

Route<T> _instantRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => child,
  );
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

