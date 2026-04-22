import '../../../../shared/models/location_point.dart';
import '../repositories/map_repository.dart';

class GetPropertyBoundaryUsecase {
  const GetPropertyBoundaryUsecase(this.repository);

  final MapRepository repository;

  Future<List<LocationPoint>> call(String propertyId) {
    return repository.getPropertyBoundary(propertyId);
  }
}
