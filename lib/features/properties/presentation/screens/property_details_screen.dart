import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/property_contact_bar.dart';
import '../widgets/property_map_preview.dart';

class PropertyDetailsScreen extends StatelessWidget {
  const PropertyDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffoldShell(
      title: 'Property Details',
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            PropertyMapPreview(),
            Spacer(),
            PropertyContactBar(),
          ],
        ),
      ),
    );
  }
}
