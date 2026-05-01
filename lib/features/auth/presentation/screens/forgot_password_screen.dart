import 'package:flutter/material.dart';

import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../../../core/widgets/app_text_field.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Forgot Password',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AppTextField(labelText: 'Email'),
            const SizedBox(height: 20),
            AppPrimaryButton(label: 'Send reset link', onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
