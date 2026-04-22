abstract final class IdGenerator {
  static String timestampId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
