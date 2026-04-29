import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

Uint8List optimizeAvatarImage(Uint8List bytes) {
  final img.Image? decodedImage = img.decodeImage(bytes);
  if (decodedImage == null) return bytes;

  final img.Image orientedImage = img.bakeOrientation(decodedImage);
  final int cropSize = math.min(orientedImage.width, orientedImage.height);
  final int cropX = ((orientedImage.width - cropSize) / 2).floor();
  final int cropY = ((orientedImage.height - cropSize) / 2).floor();
  final img.Image squareImage = img.copyCrop(
    orientedImage,
    x: cropX,
    y: cropY,
    width: cropSize,
    height: cropSize,
  );
  final int avatarSize = squareImage.width > 512 ? 512 : squareImage.width;
  final img.Image avatarImage = img.copyResize(
    squareImage,
    width: avatarSize,
    height: avatarSize,
    interpolation: img.Interpolation.average,
  );

  return Uint8List.fromList(img.encodeJpg(avatarImage, quality: 70));
}
