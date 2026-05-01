import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/auth_form.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Login',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AuthForm(submitLabel: 'Login', onSubmit: () {}),
      ),
    );
  }
}
