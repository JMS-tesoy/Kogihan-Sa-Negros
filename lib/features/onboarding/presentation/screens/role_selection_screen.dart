import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Select Role',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ListTile(
            title: const Text('Buyer'),
            onTap: () => Navigator.of(context).pushNamed(RouteNames.home),
          ),
          ListTile(
            title: const Text('Agent'),
            onTap: () =>
                Navigator.of(context).pushNamed(RouteNames.agentDashboard),
          ),
        ],
      ),
    );
  }
}
