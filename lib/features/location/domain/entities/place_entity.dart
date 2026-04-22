import '../../../../shared/models/location_point.dart';

class PlaceEntity {
  const PlaceEntity({
    required this.id,
    required this.name,
    this.location,
  });

  final String id;
  final String name;
  final LocationPoint? location;
}
