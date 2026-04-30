import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/storage_constants.dart';
import '../datasources/shared_properties.dart';

class SavedPropertyStorageService {
  const SavedPropertyStorageService._();

  static Future<Set<String>> loadSavedPropertyIds() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(StorageConstants.savedPropertyIds)
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

  static Set<Property> resolveSavedProperties({
    required Iterable<Property> availableProperties,
    required Set<String> savedPropertyIds,
  }) {
    return availableProperties
        .where((property) => savedPropertyIds.contains(property.id))
        .toSet();
  }
}
