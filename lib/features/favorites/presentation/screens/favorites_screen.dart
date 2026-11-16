import 'package:flutter/material.dart';

import '../../../search/presentation/screens/property_search_results_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PropertySearchResultsScreen(
      title: 'Favorites',
      savedOnly: true,
    );
  }
}
