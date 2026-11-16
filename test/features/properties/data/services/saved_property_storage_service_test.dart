import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/core/constants/storage_constants.dart';
import 'package:kogihan_sa_negros/features/properties/data/services/saved_property_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://127.0.0.1:54321',
      anonKey: 'test-key',
    );
  });

  tearDownAll(() async {
    await Supabase.instance.client.dispose();
  });

  group('SavedPropertyStorageService.savedPropertyIdsStorageKey', () {
    test('keeps guest saves on the existing device key', () {
      expect(
        SavedPropertyStorageService.savedPropertyIdsStorageKey(null),
        StorageConstants.savedPropertyIds,
      );
    });

    test('uses separate storage keys for different accounts', () {
      final String firstAccountKey =
          SavedPropertyStorageService.savedPropertyIdsStorageKey('user-1');
      final String secondAccountKey =
          SavedPropertyStorageService.savedPropertyIdsStorageKey('user-2');

      expect(firstAccountKey, isNot(secondAccountKey));
      expect(firstAccountKey, '${StorageConstants.savedPropertyIds}_user-1');
    });
  });

  test('saving captures the IDs before the caller mutates its set', () async {
    final Set<String> ids = <String>{'first'};
    final Future<void> save = SavedPropertyStorageService.saveSavedPropertyIds(
      ids,
    );
    ids
      ..clear()
      ..add('second');

    await save;

    expect(await SavedPropertyStorageService.loadSavedPropertyIds(), <String>{
      'first',
    });
  });
}
