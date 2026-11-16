import 'package:flutter/material.dart';

import '../../../search/presentation/screens/property_search_results_screen.dart';

class PropertyFilterScreen extends StatelessWidget {
  const PropertyFilterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PropertySearchResultsScreen(title: 'Filters');
  }
}
