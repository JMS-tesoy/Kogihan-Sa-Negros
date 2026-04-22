import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';

class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffoldShell(
      title: 'Moderation',
      body: Center(child: Text('Moderation queue')),
    );
  }
}
