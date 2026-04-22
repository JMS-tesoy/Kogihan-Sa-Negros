import '../../../../shared/models/uploaded_media.dart';
import '../repositories/agent_repository.dart';

class UploadListingImagesUsecase {
  const UploadListingImagesUsecase(this.repository);

  final AgentRepository repository;

  Future<List<UploadedMedia>> call(List<String> paths) {
    return repository.uploadListingImages(paths);
  }
}
