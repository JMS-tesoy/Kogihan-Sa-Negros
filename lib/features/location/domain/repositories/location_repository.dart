import '../../../../shared/models/location_point.dart';
import '../entities/place_entity.dart';

abstract interface class LocationRepository {
  Future<List<PlaceEntity>> getNearbyPlaces(LocationPoint point);

  Future<List<PlaceEntity>> searchPlaces(String query);
}
