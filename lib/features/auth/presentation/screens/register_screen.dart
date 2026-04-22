import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/auth_form.dart';

class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Register',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: AuthForm(
          submitLabel: 'Create account',
          showName: true,
          onSubmit: () {},
        ),
      ),
    );
  }
}
