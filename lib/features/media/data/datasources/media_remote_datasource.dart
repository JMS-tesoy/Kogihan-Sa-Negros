import '../../../../shared/models/uploaded_media.dart';

class MediaRemoteDatasource {
  Future<UploadedMedia> uploadImage(String path) async {
    return UploadedMedia(id: path, url: path, fileName: path.split('/').last);
  }

  Future<void> deleteImage(String id) async {}

  Future<String> optimizeImage(String path) async {
    return path;
  }
}
