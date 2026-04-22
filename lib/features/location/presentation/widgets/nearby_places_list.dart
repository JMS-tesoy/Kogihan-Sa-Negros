import 'package:flutter/material.dart';

import '../../domain/entities/place_entity.dart';

class NearbyPlacesList extends StatelessWidget {
  const NearbyPlacesList({
    super.key,
    required this.places,
  });

  final List<PlaceEntity> places;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: places.map((place) => ListTile(title: Text(place.name))).toList(),
    );
  }
}
