import '../../../properties/data/models/property_model.dart';

class FavoritesRemoteDatasource {
  Future<List<PropertyModel>> getSavedProperties() async {
    return const <PropertyModel>[];
  }

  Future<void> toggleFavorite(String propertyId) async {}
}
