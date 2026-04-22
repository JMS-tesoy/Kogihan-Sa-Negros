import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Onboarding',
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).pushNamed(RouteNames.roleSelection);
          },
          child: const Text('Choose role'),
        ),
      ),
    );
  }
}
