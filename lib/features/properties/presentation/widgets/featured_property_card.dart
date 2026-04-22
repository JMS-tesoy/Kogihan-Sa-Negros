import 'package:flutter/material.dart';

import '../../domain/entities/property_entity.dart';
import 'property_card.dart';

class FeaturedPropertyCard extends StatelessWidget {
  const FeaturedPropertyCard({
    super.key,
    required this.property,
    this.onTap,
  });

  final PropertyEntity property;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PropertyCard(
      property: property,
      onTap: onTap,
    );
  }
}
