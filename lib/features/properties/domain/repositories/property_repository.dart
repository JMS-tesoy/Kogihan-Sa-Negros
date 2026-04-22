import '../entities/property_entity.dart';
import '../entities/property_filter_entity.dart';

abstract interface class PropertyRepository {
  Future<List<PropertyEntity>> getProperties({PropertyFilterEntity? filter});

  Future<PropertyEntity?> getPropertyDetails(String id);

  Future<List<PropertyEntity>> searchProperties(String query);

  Future<List<PropertyEntity>> getFeaturedProperties();

  Future<void> saveProperty(String id);

  Future<void> unsaveProperty(String id);
}
