import 'storage_service.dart';

class SecureStorageService {
  SecureStorageService({StorageService? storage})
    : _storage = storage ?? StorageService();

  final StorageService _storage;

  Future<void> write(String key, String value) =>
      _storage.setString(key, value);

  Future<String?> read(String key) => _storage.getString(key);

  Future<void> delete(String key) => _storage.remove(key);
}
