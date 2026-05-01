import '../../shared/models/uploaded_media.dart';

class FileUploadService {
  Future<UploadedMedia> upload(String path) async {
    return UploadedMedia(id: path, url: path, fileName: path.split('/').last);
  }
}
