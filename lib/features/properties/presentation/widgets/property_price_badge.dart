import 'package:flutter/material.dart';

import '../../../../core/utils/currency_formatters.dart';

class PropertyPriceBadge extends StatelessWidget {
  const PropertyPriceBadge({
    super.key,
    required this.price,
  });

  final num price;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text(CurrencyFormatters.php(price)));
  }
}
