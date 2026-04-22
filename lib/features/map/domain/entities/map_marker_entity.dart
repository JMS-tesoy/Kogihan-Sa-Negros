import '../../../../shared/models/location_point.dart';

class MapMarkerEntity {
  const MapMarkerEntity({
    required this.id,
    required this.title,
    required this.location,
    this.propertyId,
  });

  final String id;
  final String title;
  final LocationPoint location;
  final String? propertyId;
}
