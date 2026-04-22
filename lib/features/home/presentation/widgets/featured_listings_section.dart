import 'package:flutter/material.dart';

import '../../../../core/widgets/app_section_header.dart';

class FeaturedListingsSection extends StatelessWidget {
  const FeaturedListingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        AppSectionHeader(title: 'Featured listings'),
        SizedBox(height: 12),
        Text('Featured property cards will appear here.'),
      ],
    );
  }
}
