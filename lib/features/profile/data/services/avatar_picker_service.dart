import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import 'avatar_image_optimizer.dart';

class AvatarPickerService {
  AvatarPickerService._();

  static final ImagePicker _imagePicker = ImagePicker();

  static Future<Uint8List?> pickGalleryAvatar() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (pickedFile == null) return null;

    return optimizeAvatarImage(await pickedFile.readAsBytes());
  }

  static Future<Uint8List?> pickCameraAvatar() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );
    if (pickedFile == null) return null;

    return pickedFile.readAsBytes();
  }
}
