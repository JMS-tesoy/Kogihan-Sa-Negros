import '../../../../shared/models/uploaded_media.dart';

abstract interface class MediaRepository {
  Future<UploadedMedia> uploadImage(String path);

  Future<void> deleteImage(String id);

  Future<String> optimizeImage(String path);
}
