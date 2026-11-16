import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/storage_constants.dart';
import '../datasources/shared_properties.dart';

class SavedPropertiesSnapshot {
  final Set<String> savedPropertyIds;
  final Set<Property> savedProperties;

  const SavedPropertiesSnapshot({
    required this.savedPropertyIds,
    required this.savedProperties,
  });
}

class SavedPropertyStorageService {
  const SavedPropertyStorageService._();

  static String savedPropertyIdsStorageKey(String? userId) {
    final String normalizedUserId = (userId ?? '').trim();
    if (normalizedUserId.isEmpty) return StorageConstants.savedPropertyIds;
    return '${StorageConstants.savedPropertyIds}_$normalizedUserId';
  }

  static String get _currentStorageKey {
    final String? userId = Supabase.instance.client.auth.currentUser?.id;
    return savedPropertyIdsStorageKey(userId);
  }

  static Future<Set<String>> loadSavedPropertyIds() async {
    final String storageKey = _currentStorageKey;
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(storageKey)?.toSet() ?? <String>{};
  }

  static Future<void> saveSavedPropertyIds(Set<String> propertyIds) async {
    final String storageKey = _currentStorageKey;
    final List<String> ids = propertyIds.toList();
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final bool saved = await preferences.setStringList(storageKey, ids);
    if (!saved) {
      throw StateError('Failed to persist saved properties.');
    }
  }

  static Future<SavedPropertiesSnapshot> loadSavedProperties({
    required Iterable<Property> availableProperties,
  }) async {
    final Set<String> savedPropertyIds = await loadSavedPropertyIds();
    return SavedPropertiesSnapshot(
      savedPropertyIds: savedPropertyIds,
      savedProperties: resolveSavedProperties(
        availableProperties: availableProperties,
        savedPropertyIds: savedPropertyIds,
      ),
    );
  }

  static Set<Property> resolveSavedProperties({
    required Iterable<Property> availableProperties,
    required Set<String> savedPropertyIds,
  }) {
    return availableProperties
        .where((property) => savedPropertyIds.contains(property.id))
        .toSet();
  }

  static bool shouldShowUpgradePrompt({
    required bool isAlreadySaved,
    required bool isPremium,
    required int savedCount,
    required int freeLimit,
  }) {
    return !isAlreadySaved && !isPremium && savedCount >= freeLimit;
  }

  static void toggleSavedProperty({
    required Property property,
    required Set<Property> savedProperties,
    required Set<String> savedPropertyIds,
  }) {
    if (savedProperties.contains(property)) {
      savedProperties.remove(property);
      savedPropertyIds.remove(property.id);
    } else {
      savedProperties.add(property);
      savedPropertyIds.add(property.id);
    }
  }
}
