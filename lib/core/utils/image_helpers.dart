abstract final class ImageHelpers {
  static bool isNetworkImage(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }
}
