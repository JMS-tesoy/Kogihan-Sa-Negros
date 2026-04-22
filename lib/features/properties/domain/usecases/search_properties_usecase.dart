import '../entities/property_entity.dart';
import '../repositories/property_repository.dart';

class SearchPropertiesUsecase {
  const SearchPropertiesUsecase(this.repository);

  final PropertyRepository repository;

  Future<List<PropertyEntity>> call(String query) {
    return repository.searchProperties(query);
  }
}
