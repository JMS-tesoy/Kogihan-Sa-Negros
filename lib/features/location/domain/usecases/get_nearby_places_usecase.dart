import '../../../../shared/models/location_point.dart';
import '../entities/place_entity.dart';
import '../repositories/location_repository.dart';

class GetNearbyPlacesUsecase {
  const GetNearbyPlacesUsecase(this.repository);

  final LocationRepository repository;

  Future<List<PlaceEntity>> call(LocationPoint point) {
    return repository.getNearbyPlaces(point);
  }
}
