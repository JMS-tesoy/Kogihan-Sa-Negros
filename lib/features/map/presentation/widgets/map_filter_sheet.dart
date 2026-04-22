import 'package:flutter/material.dart';

import '../../../../core/widgets/app_search_field.dart';

class MapFilterSheet extends StatelessWidget {
  const MapFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: AppSearchField(hintText: 'Filter map'),
    );
  }
}
