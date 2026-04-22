import '../entities/place_entity.dart';
import '../repositories/location_repository.dart';

class SearchPlacesUsecase {
  const SearchPlacesUsecase(this.repository);

  final LocationRepository repository;

  Future<List<PlaceEntity>> call(String query) {
    return repository.searchPlaces(query);
  }
}
