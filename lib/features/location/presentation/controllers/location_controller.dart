import 'package:flutter/foundation.dart';

import '../../domain/entities/place_entity.dart';
import '../../domain/usecases/search_places_usecase.dart';

class LocationController extends ChangeNotifier {
  LocationController({this.searchPlacesUsecase});

  final SearchPlacesUsecase? searchPlacesUsecase;

  List<PlaceEntity> _places = const <PlaceEntity>[];

  List<PlaceEntity> get places => _places;

  Future<void> search(String query) async {
    _places = await searchPlacesUsecase?.call(query) ?? const <PlaceEntity>[];
    notifyListeners();
  }
}
