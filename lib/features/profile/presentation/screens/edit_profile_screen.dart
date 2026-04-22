import 'package:flutter/material.dart';

import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../../../core/widgets/app_text_field.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Edit Profile',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AppTextField(labelText: 'Name'),
            const SizedBox(height: 12),
            const AppTextField(labelText: 'Phone'),
            const SizedBox(height: 20),
            AppPrimaryButton(label: 'Save', onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
