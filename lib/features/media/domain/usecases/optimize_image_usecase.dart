import '../repositories/media_repository.dart';

class OptimizeImageUsecase {
  const OptimizeImageUsecase(this.repository);

  final MediaRepository repository;

  Future<String> call(String path) {
    return repository.optimizeImage(path);
  }
}
