import '../repositories/property_repository.dart';

class UnsavePropertyUsecase {
  const UnsavePropertyUsecase(this.repository);

  final PropertyRepository repository;

  Future<void> call(String id) {
    return repository.unsaveProperty(id);
  }
}
