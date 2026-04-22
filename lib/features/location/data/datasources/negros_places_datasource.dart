import '../models/place_model.dart';

class NegrosPlacesDatasource {
  Future<List<PlaceModel>> searchPlaces(String query) async {
    const places = <PlaceModel>[
      PlaceModel(id: 'bacolod', name: 'Bacolod'),
      PlaceModel(id: 'dumaguete', name: 'Dumaguete'),
    ];

    if (query.trim().isEmpty) {
      return places;
    }

    return places
        .where(
          (place) => place.name.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }
}
