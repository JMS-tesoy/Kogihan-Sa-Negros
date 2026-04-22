import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/agent_stats_header.dart';

class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Agent Dashboard',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const AgentStatsHeader(),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pushNamed(
              RouteNames.createListing,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Create listing'),
          ),
        ],
      ),
    );
  }
}
