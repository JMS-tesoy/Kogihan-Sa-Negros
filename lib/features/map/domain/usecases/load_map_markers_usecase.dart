import '../entities/map_marker_entity.dart';
import '../repositories/map_repository.dart';

class LoadMapMarkersUsecase {
  const LoadMapMarkersUsecase(this.repository);

  final MapRepository repository;

  Future<List<MapMarkerEntity>> call() {
    return repository.loadMarkers();
  }
}
