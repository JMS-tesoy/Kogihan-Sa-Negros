import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/boundary_editor.dart';
import '../widgets/listing_form.dart';
import '../widgets/media_upload_grid.dart';

class CreateListingScreen extends StatelessWidget {
  const CreateListingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Create Listing',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          ListingForm(submitLabel: 'Create listing', onSubmit: () {}),
          const SizedBox(height: 20),
          const BoundaryEditor(),
          const SizedBox(height: 20),
          const MediaUploadGrid(),
        ],
      ),
    );
  }
}
