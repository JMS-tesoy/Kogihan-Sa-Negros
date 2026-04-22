import '../../../../shared/models/location_point.dart';
import '../models/map_marker_model.dart';

class MapRemoteDatasource {
  Future<List<MapMarkerModel>> loadMarkers() async {
    return const <MapMarkerModel>[];
  }

  Future<List<LocationPoint>> getPropertyBoundary(String propertyId) async {
    return const <LocationPoint>[];
  }
}
