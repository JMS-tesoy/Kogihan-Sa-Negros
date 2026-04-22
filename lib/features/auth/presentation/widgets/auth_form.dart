import 'package:flutter/material.dart';

import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class AuthForm extends StatelessWidget {
  const AuthForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
    this.showName = false,
  });

  final String submitLabel;
  final VoidCallback onSubmit;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showName) ...<Widget>[
          const AppTextField(labelText: 'Name'),
          const SizedBox(height: 12),
        ],
        const AppTextField(labelText: 'Email'),
        const SizedBox(height: 12),
        const AppTextField(
          labelText: 'Password',
          obscureText: true,
        ),
        const SizedBox(height: 20),
        AppPrimaryButton(
          label: submitLabel,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}
