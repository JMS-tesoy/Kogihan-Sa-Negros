import 'package:flutter/material.dart';

import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class InquiryFormSheet extends StatelessWidget {
  const InquiryFormSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AppTextField(labelText: 'Message'),
          const SizedBox(height: 16),
          AppPrimaryButton(
            label: 'Send inquiry',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
