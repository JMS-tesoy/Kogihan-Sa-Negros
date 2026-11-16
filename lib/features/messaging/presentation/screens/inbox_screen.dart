import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import 'messages_tab.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffoldShell(
      title: 'Inbox',
      body: MessagesTab(showHeader: false),
    );
  }
}
