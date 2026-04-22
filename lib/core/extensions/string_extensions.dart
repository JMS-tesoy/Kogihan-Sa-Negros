extension StringExtensions on String {
  bool get isBlank => trim().isEmpty;

  String get capitalized {
    if (isEmpty) {
      return this;
    }

    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
