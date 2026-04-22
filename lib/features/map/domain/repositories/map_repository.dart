import '../../../../shared/models/location_point.dart';
import '../entities/map_marker_entity.dart';

abstract interface class MapRepository {
  Future<List<MapMarkerEntity>> loadMarkers();

  Future<List<LocationPoint>> getPropertyBoundary(String propertyId);
}
