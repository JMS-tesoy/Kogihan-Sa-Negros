import '../../../../shared/models/location_point.dart';
import '../../domain/entities/place_entity.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_remote_datasource.dart';
import '../datasources/negros_places_datasource.dart';

class LocationRepositoryImpl implements LocationRepository {
  LocationRepositoryImpl({
    LocationRemoteDatasource? remoteDatasource,
    NegrosPlacesDatasource? placesDatasource,
  }) : _remoteDatasource = remoteDatasource ?? LocationRemoteDatasource(),
       _placesDatasource = placesDatasource ?? NegrosPlacesDatasource();

  final LocationRemoteDatasource _remoteDatasource;
  final NegrosPlacesDatasource _placesDatasource;

  @override
  Future<List<PlaceEntity>> getNearbyPlaces(LocationPoint point) {
    return _remoteDatasource.getNearbyPlaces(point);
  }

  @override
  Future<List<PlaceEntity>> searchPlaces(String query) {
    return _placesDatasource.searchPlaces(query);
  }
}
