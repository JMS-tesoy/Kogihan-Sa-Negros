import 'package:flutter/material.dart';

class PropertyMetaRow extends StatelessWidget {
  const PropertyMetaRow({
    super.key,
    required this.address,
    required this.listingType,
  });

  final String address;
  final String listingType;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.place, size: 16),
        const SizedBox(width: 4),
        Expanded(child: Text(address)),
        const SizedBox(width: 8),
        Text(listingType),
      ],
    );
  }
}
