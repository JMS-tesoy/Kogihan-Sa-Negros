import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';

class PropertyFilterScreen extends StatelessWidget {
  const PropertyFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffoldShell(
      title: 'Filters',
      body: Center(child: Text('Property filters')),
    );
  }
}
