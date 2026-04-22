import '../entities/property_entity.dart';
import '../repositories/property_repository.dart';

class GetFeaturedPropertiesUsecase {
  const GetFeaturedPropertiesUsecase(this.repository);

  final PropertyRepository repository;

  Future<List<PropertyEntity>> call() {
    return repository.getFeaturedProperties();
  }
}
