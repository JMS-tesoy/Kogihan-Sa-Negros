import 'package:flutter/material.dart';

import '../../domain/entities/property_entity.dart';
import 'property_card.dart';

class PropertyGrid extends StatelessWidget {
  const PropertyGrid({super.key, required this.properties});

  final List<PropertyEntity> properties;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: properties.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) {
        return PropertyCard(property: properties[index]);
      },
    );
  }
}
