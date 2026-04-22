import 'package:flutter/material.dart';

import '../../../../core/widgets/app_section_header.dart';

class NearbyPropertiesSection extends StatelessWidget {
  const NearbyPropertiesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppSectionHeader(title: 'Nearby properties'),
        SizedBox(height: 12),
        Text('Nearby property results will appear here.'),
      ],
    );
  }
}
