import '../entities/property_entity.dart';
import '../repositories/property_repository.dart';

class GetPropertyDetailsUsecase {
  const GetPropertyDetailsUsecase(this.repository);

  final PropertyRepository repository;

  Future<PropertyEntity?> call(String id) {
    return repository.getPropertyDetails(id);
  }
}
