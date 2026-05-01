import '../../../../shared/models/location_point.dart';
import '../../domain/entities/map_marker_entity.dart';
import '../../domain/repositories/map_repository.dart';
import '../datasources/map_remote_datasource.dart';

class MapRepositoryImpl implements MapRepository {
  MapRepositoryImpl({MapRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? MapRemoteDatasource();

  final MapRemoteDatasource _remoteDatasource;

  @override
  Future<List<MapMarkerEntity>> loadMarkers() {
    return _remoteDatasource.loadMarkers();
  }

  @override
  Future<List<LocationPoint>> getPropertyBoundary(String propertyId) {
    return _remoteDatasource.getPropertyBoundary(propertyId);
  }
}
