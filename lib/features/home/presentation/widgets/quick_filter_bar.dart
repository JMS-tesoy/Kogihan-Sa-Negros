import 'package:flutter/material.dart';

class QuickFilterBar extends StatelessWidget {
  const QuickFilterBar({
    super.key,
    this.filters = const <String>['All', 'Sale', 'Rent'],
    this.onSelected,
  });

  final List<String> filters;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: filters.map((filter) {
        return ActionChip(
          label: Text(filter),
          onPressed: () => onSelected?.call(filter),
        );
      }).toList(),
    );
  }
}
