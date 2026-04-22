import 'package:flutter/foundation.dart';

import '../../domain/entities/map_marker_entity.dart';
import '../../domain/usecases/load_map_markers_usecase.dart';

class MapController extends ChangeNotifier {
  MapController({this.loadMapMarkersUsecase});

  final LoadMapMarkersUsecase? loadMapMarkersUsecase;

  List<MapMarkerEntity> _markers = const <MapMarkerEntity>[];

  List<MapMarkerEntity> get markers => _markers;

  Future<void> load() async {
    _markers = await loadMapMarkersUsecase?.call() ?? const <MapMarkerEntity>[];
    notifyListeners();
  }
}
