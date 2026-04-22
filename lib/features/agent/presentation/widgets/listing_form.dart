import 'package:flutter/material.dart';

import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class ListingForm extends StatelessWidget {
  const ListingForm({
    super.key,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String submitLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AppTextField(labelText: 'Title'),
        const SizedBox(height: 12),
        const AppTextField(labelText: 'Price'),
        const SizedBox(height: 12),
        const AppTextField(labelText: 'Address'),
        const SizedBox(height: 20),
        AppPrimaryButton(label: submitLabel, onPressed: onSubmit),
      ],
    );
  }
}
