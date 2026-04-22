import 'package:flutter/material.dart';

import '../../domain/entities/property_entity.dart';

class PropertyListTile extends StatelessWidget {
  const PropertyListTile({
    super.key,
    required this.property,
    this.onTap,
  });

  final PropertyEntity property;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(property.title),
      subtitle: Text(property.address),
      trailing: Text(property.price.toStringAsFixed(0)),
      onTap: onTap,
    );
  }
}
