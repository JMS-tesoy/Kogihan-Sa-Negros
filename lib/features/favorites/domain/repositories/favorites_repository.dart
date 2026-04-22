import '../../../properties/domain/entities/property_entity.dart';

abstract interface class FavoritesRepository {
  Future<List<PropertyEntity>> getSavedProperties();

  Future<void> toggleFavorite(String propertyId);
}
