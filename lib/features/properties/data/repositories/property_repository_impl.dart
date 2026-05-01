import '../../domain/entities/property_entity.dart';
import '../../domain/entities/property_filter_entity.dart';
import '../../domain/repositories/property_repository.dart';
import '../datasources/properties_local_datasource.dart';
import '../datasources/properties_remote_datasource.dart';

class PropertyRepositoryImpl implements PropertyRepository {
  PropertyRepositoryImpl({
    PropertiesRemoteDatasource? remoteDatasource,
    PropertiesLocalDatasource? localDatasource,
  }) : _remoteDatasource = remoteDatasource ?? PropertiesRemoteDatasource(),
       _localDatasource = localDatasource ?? PropertiesLocalDatasource();

  final PropertiesRemoteDatasource _remoteDatasource;
  final PropertiesLocalDatasource _localDatasource;

  @override
  Future<List<PropertyEntity>> getProperties({PropertyFilterEntity? filter}) {
    return _remoteDatasource.getProperties();
  }

  @override
  Future<PropertyEntity?> getPropertyDetails(String id) {
    return _remoteDatasource.getPropertyDetails(id);
  }

  @override
  Future<List<PropertyEntity>> getFeaturedProperties() {
    return _remoteDatasource.getProperties();
  }

  @override
  Future<List<PropertyEntity>> searchProperties(String query) {
    return _remoteDatasource.getProperties();
  }

  @override
  Future<void> saveProperty(String id) {
    return _localDatasource.saveProperty(id);
  }

  @override
  Future<void> unsaveProperty(String id) {
    return _localDatasource.unsaveProperty(id);
  }
}
