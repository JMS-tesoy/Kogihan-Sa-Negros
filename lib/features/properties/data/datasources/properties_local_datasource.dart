class PropertiesLocalDatasource {
  final Set<String> _savedIds = <String>{};

  Future<void> saveProperty(String id) async {
    _savedIds.add(id);
  }

  Future<void> unsaveProperty(String id) async {
    _savedIds.remove(id);
  }

  Future<bool> isSaved(String id) async {
    return _savedIds.contains(id);
  }
}
