extension NumExtensions on num {
  String get asCurrency {
    return 'PHP ${toStringAsFixed(2)}';
  }
}
