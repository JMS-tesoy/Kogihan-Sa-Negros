import 'package:flutter/material.dart';

import '../../domain/entities/place_entity.dart';

class PlaceChip extends StatelessWidget {
  const PlaceChip({super.key, required this.place, this.onSelected});

  final PlaceEntity place;
  final ValueChanged<PlaceEntity>? onSelected;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(place.name),
      onPressed: () => onSelected?.call(place),
    );
  }
}
