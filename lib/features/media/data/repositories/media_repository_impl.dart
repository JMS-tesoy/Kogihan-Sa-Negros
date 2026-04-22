import '../../../../shared/models/uploaded_media.dart';
import '../../domain/repositories/media_repository.dart';
import '../datasources/media_remote_datasource.dart';

class MediaRepositoryImpl implements MediaRepository {
  MediaRepositoryImpl({MediaRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? MediaRemoteDatasource();

  final MediaRemoteDatasource _remoteDatasource;

  @override
  Future<void> deleteImage(String id) {
    return _remoteDatasource.deleteImage(id);
  }

  @override
  Future<String> optimizeImage(String path) {
    return _remoteDatasource.optimizeImage(path);
  }

  @override
  Future<UploadedMedia> uploadImage(String path) {
    return _remoteDatasource.uploadImage(path);
  }
}
