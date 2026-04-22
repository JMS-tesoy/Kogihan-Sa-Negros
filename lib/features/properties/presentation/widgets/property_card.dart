import 'package:flutter/material.dart';

import '../../domain/entities/property_entity.dart';
import 'property_meta_row.dart';
import 'property_price_badge.dart';

class PropertyCard extends StatelessWidget {
  const PropertyCard({
    super.key,
    required this.property,
    this.onTap,
  });

  final PropertyEntity property;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                property.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              PropertyPriceBadge(price: property.price),
              const SizedBox(height: 8),
              PropertyMetaRow(
                address: property.address,
                listingType: property.listingType.name,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
