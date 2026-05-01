import 'package:shared_preferences/shared_preferences.dart';

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

  static Future<Set<String>> loadSavedPropertyIds() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences
            .getStringList(StorageConstants.savedPropertyIds)
            ?.toSet() ??
        <String>{};
  }

  static Future<void> saveSavedPropertyIds(Set<String> propertyIds) async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      StorageConstants.savedPropertyIds,
      propertyIds.toList(),
    );
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
