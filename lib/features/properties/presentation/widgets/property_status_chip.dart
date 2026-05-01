import 'package:flutter/material.dart';

import '../../../../core/enums/property_status.dart';

class PropertyStatusChip extends StatelessWidget {
  const PropertyStatusChip({super.key, required this.status});

  final PropertyStatus status;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(status.name));
  }
}
