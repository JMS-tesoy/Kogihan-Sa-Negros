import '../entities/property_entity.dart';
import '../entities/property_filter_entity.dart';
import '../repositories/property_repository.dart';

class GetPropertiesUsecase {
  const GetPropertiesUsecase(this.repository);

  final PropertyRepository repository;

  Future<List<PropertyEntity>> call({PropertyFilterEntity? filter}) {
    return repository.getProperties(filter: filter);
  }
}
