import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffoldShell(
      title: 'Inbox',
      body: AppEmptyState(message: 'No conversations yet.'),
    );
  }
}
