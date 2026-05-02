import 'dart:typed_data';

import 'property_upload_service.dart';

class PropertyImageService {
  PropertyImageService({PropertyUploadService? uploadService})
    : _uploadService = uploadService ?? PropertyUploadService();

  final PropertyUploadService _uploadService;

  Future<String> uploadPropertyImage(String fileName, Uint8List fileBytes) {
    return _uploadService.uploadImage(fileBytes, fileName);
  }
}
