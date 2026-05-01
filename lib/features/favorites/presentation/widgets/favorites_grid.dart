import 'package:flutter/material.dart';

import '../../../properties/domain/entities/property_entity.dart';
import '../../../properties/presentation/widgets/property_card.dart';

class FavoritesGrid extends StatelessWidget {
  const FavoritesGrid({super.key, required this.properties});

  final List<PropertyEntity> properties;

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return const Center(child: Text('No favorites yet.'));
    }

    return ListView(
      children: properties.map((property) {
        return PropertyCard(property: property);
      }).toList(),
    );
  }
}
