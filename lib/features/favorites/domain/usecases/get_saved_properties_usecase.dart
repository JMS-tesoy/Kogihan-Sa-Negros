import '../../../properties/domain/entities/property_entity.dart';
import '../repositories/favorites_repository.dart';

class GetSavedPropertiesUsecase {
  const GetSavedPropertiesUsecase(this.repository);

  final FavoritesRepository repository;

  Future<List<PropertyEntity>> call() {
    return repository.getSavedProperties();
  }
}
