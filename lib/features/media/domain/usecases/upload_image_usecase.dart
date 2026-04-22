import '../../../../shared/models/uploaded_media.dart';
import '../repositories/media_repository.dart';

class UploadImageUsecase {
  const UploadImageUsecase(this.repository);

  final MediaRepository repository;

  Future<UploadedMedia> call(String path) {
    return repository.uploadImage(path);
  }
}
