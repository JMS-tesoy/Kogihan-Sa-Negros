import '../repositories/media_repository.dart';

class DeleteImageUsecase {
  const DeleteImageUsecase(this.repository);

  final MediaRepository repository;

  Future<void> call(String id) {
    return repository.deleteImage(id);
  }
}
