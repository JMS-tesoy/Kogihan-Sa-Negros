import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/listing_form.dart';

class EditListingScreen extends StatelessWidget {
  const EditListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Edit Listing',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListingForm(submitLabel: 'Save changes', onSubmit: () {}),
      ),
    );
  }
}
