import '../repositories/property_repository.dart';

class SavePropertyUsecase {
  const SavePropertyUsecase(this.repository);

  final PropertyRepository repository;

  Future<void> call(String id) {
    return repository.saveProperty(id);
  }
}
