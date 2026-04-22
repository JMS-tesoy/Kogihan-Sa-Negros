import '../../../../shared/models/location_point.dart';
import '../models/place_model.dart';

class LocationRemoteDatasource {
  Future<List<PlaceModel>> getNearbyPlaces(LocationPoint point) async {
    return const <PlaceModel>[];
  }
}
