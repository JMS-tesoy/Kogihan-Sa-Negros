import 'package:flutter/material.dart';

import '../../../search/presentation/screens/property_search_results_screen.dart';

class PropertyListScreen extends StatelessWidget {
  const PropertyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PropertySearchResultsScreen(title: 'Properties');
  }
}
