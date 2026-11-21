import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import 'admin_stats_header.dart';

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({
    required this.properties,
    required this.agents,
    required this.pendingRequests,
    required this.users,
    required this.onSelectTab,
    super.key,
  });

  final int? properties;
  final int agents;
  final int pendingRequests;
  final int users;
  final ValueChanged<int> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final String requestSummary = switch (pendingRequests) {
      0 => 'No pending requests to review.',
      1 => '1 pending request needs review.',
      _ => '$pendingRequests pending requests need review.',
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: <Widget>[
        AdminStatsHeader(
          properties: properties,
          agents: agents,
          pendingRequests: pendingRequests,
          users: users,
        ),
        const SizedBox(height: 24),
        Text(
          'Quick actions',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: colorScheme.primaryContainer,
          margin: EdgeInsets.zero,
          child: ListTile(
            onTap: () => onSelectTab(2),
            leading: Icon(
              Icons.pending_actions_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
            title: Text(
              'Review team requests',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              requestSummary,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_rounded,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _OverviewActionTile(
          icon: Icons.shield_outlined,
          title: 'Moderate listings and reports',
          subtitle: 'Review pending submissions and community reports.',
          onTap: () => Navigator.of(context).pushNamed(RouteNames.moderation),
        ),
        const SizedBox(height: 8),
        _OverviewActionTile(
          icon: Icons.support_agent_rounded,
          title: 'Manage agents',
          subtitle: 'Manage agent profiles and teams.',
          onTap: () => onSelectTab(1),
        ),
        const SizedBox(height: 8),
        _OverviewActionTile(
          icon: Icons.people_outline_rounded,
          title: 'Browse users',
          subtitle: 'View registered user accounts.',
          onTap: () => onSelectTab(3),
        ),
      ],
    );
  }
}

class _OverviewActionTile extends StatelessWidget {
  const _OverviewActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_rounded),
      ),
    );
  }
}
