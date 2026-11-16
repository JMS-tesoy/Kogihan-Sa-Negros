import 'package:flutter/material.dart';

class AdminStatsHeader extends StatelessWidget {
  const AdminStatsHeader({
    required this.properties,
    required this.agents,
    required this.pendingRequests,
    required this.users,
    super.key,
  });

  final int? properties;
  final int agents;
  final int pendingRequests;
  final int users;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _AdminStatCard(
            label: 'Listings',
            count: properties,
            icon: Icons.home_work_outlined,
          ),
          _AdminStatCard(
            label: 'Agents',
            count: agents,
            icon: Icons.support_agent_rounded,
          ),
          _AdminStatCard(
            label: 'Pending requests',
            count: pendingRequests,
            icon: Icons.pending_actions_rounded,
          ),
          _AdminStatCard(
            label: 'Users',
            count: users,
            icon: Icons.people_outline_rounded,
          ),
        ],
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.label,
    required this.count,
    required this.icon,
  });

  final String label;
  final int? count;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return SizedBox(
      width: 140,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 20, color: colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                count?.toString() ?? '—',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
