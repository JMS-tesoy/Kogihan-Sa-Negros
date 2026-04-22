import '../../../../shared/models/location_point.dart';
import '../../domain/entities/map_marker_entity.dart';

class MapMarkerModel extends MapMarkerEntity {
  const MapMarkerModel({
    required super.id,
    required super.title,
    required super.location,
    super.propertyId,
  });

  factory MapMarkerModel.fromJson(Map<String, dynamic> json) {
    return MapMarkerModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      location: LocationPoint(
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      ),
      propertyId: json['propertyId'] as String?,
    );
  }
}
