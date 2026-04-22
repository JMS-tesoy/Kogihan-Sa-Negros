import '../../../properties/domain/entities/property_entity.dart';
import '../../domain/repositories/favorites_repository.dart';
import '../datasources/favorites_remote_datasource.dart';

class FavoritesRepositoryImpl implements FavoritesRepository {
  FavoritesRepositoryImpl({FavoritesRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? FavoritesRemoteDatasource();

  final FavoritesRemoteDatasource _remoteDatasource;

  @override
  Future<List<PropertyEntity>> getSavedProperties() {
    return _remoteDatasource.getSavedProperties();
  }

  @override
  Future<void> toggleFavorite(String propertyId) {
    return _remoteDatasource.toggleFavorite(propertyId);
  }
}
