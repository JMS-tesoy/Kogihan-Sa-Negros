import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';

class PlansScreen extends StatelessWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffoldShell(
      title: 'Plans',
      body: AppEmptyState(message: 'Plans will appear here.'),
    );
  }
}
