import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/place_model.dart';

class NegrosPlace {
  final int id;
  final String placeName;
  final String province;
  final String location;

  const NegrosPlace({
    required this.id,
    required this.placeName,
    required this.province,
    required this.location,
  });

  factory NegrosPlace.fromMap(Map<String, dynamic> map) {
    return NegrosPlace(
      id: _toInt(map['id']),
      placeName: (map['place_name'] ?? '').toString(),
      province: (map['province'] ?? '').toString(),
      location: (map['location'] ?? '').toString(),
    );
  }

  double? get latitude {
    final List<String> parts = location.split(',');
    if (parts.length < 2) return null;
    return double.tryParse(parts[0].trim());
  }

  double? get longitude {
    final List<String> parts = location.split(',');
    if (parts.length < 2) return null;
    return double.tryParse(parts[1].trim());
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

const List<NegrosPlace> _fallbackNegrosPlaces = [
  NegrosPlace(
    id: 1,
    placeName: 'Bacolod City',
    province: 'Negros Occidental',
    location: '10.6676,122.9503',
  ),
  NegrosPlace(
    id: 2,
    placeName: 'Bago City',
    province: 'Negros Occidental',
    location: '10.5389,122.8366',
  ),
  NegrosPlace(
    id: 3,
    placeName: 'San Carlos City',
    province: 'Negros Occidental',
    location: '10.4824,123.4183',
  ),
  NegrosPlace(
    id: 4,
    placeName: 'La Carlota City',
    province: 'Negros Occidental',
    location: '10.4253,122.9224',
  ),
  NegrosPlace(
    id: 5,
    placeName: 'Cadiz City',
    province: 'Negros Occidental',
    location: '10.9545,123.3058',
  ),
  NegrosPlace(
    id: 6,
    placeName: 'Escalante City',
    province: 'Negros Occidental',
    location: '10.8412,123.4992',
  ),
  NegrosPlace(
    id: 7,
    placeName: 'Silay City',
    province: 'Negros Occidental',
    location: '10.7977,122.9730',
  ),
  NegrosPlace(
    id: 8,
    placeName: 'Victorias City',
    province: 'Negros Occidental',
    location: '10.8962,123.0726',
  ),
  NegrosPlace(
    id: 9,
    placeName: 'Sagay City',
    province: 'Negros Occidental',
    location: '10.9000,123.4167',
  ),
  NegrosPlace(
    id: 10,
    placeName: 'Talisay City',
    province: 'Negros Occidental',
    location: '10.7333,122.9667',
  ),
  NegrosPlace(
    id: 11,
    placeName: 'Himamaylan City',
    province: 'Negros Occidental',
    location: '10.1000,122.8667',
  ),
  NegrosPlace(
    id: 12,
    placeName: 'Kabankalan City',
    province: 'Negros Occidental',
    location: '9.9833,122.8167',
  ),
  NegrosPlace(
    id: 13,
    placeName: 'Sipalay City',
    province: 'Negros Occidental',
    location: '9.7500,122.4000',
  ),
  NegrosPlace(
    id: 14,
    placeName: 'Dumaguete City',
    province: 'Negros Oriental',
    location: '9.3054,123.3080',
  ),
  NegrosPlace(
    id: 15,
    placeName: 'Bayawan City',
    province: 'Negros Oriental',
    location: '9.3668,122.8055',
  ),
  NegrosPlace(
    id: 16,
    placeName: 'Bais City',
    province: 'Negros Oriental',
    location: '9.5914,123.1213',
  ),
  NegrosPlace(
    id: 17,
    placeName: 'Guihulngan City',
    province: 'Negros Oriental',
    location: '10.1199,123.2728',
  ),
  NegrosPlace(
    id: 18,
    placeName: 'Canlaon City',
    province: 'Negros Oriental',
    location: '10.3833,123.2167',
  ),
  NegrosPlace(
    id: 19,
    placeName: 'Tanjay City',
    province: 'Negros Oriental',
    location: '9.5121,123.1596',
  ),
  NegrosPlace(
    id: 20,
    placeName: 'Bacong',
    province: 'Negros Oriental',
    location: '9.2452,123.2951',
  ),
  NegrosPlace(
    id: 21,
    placeName: 'Dauin',
    province: 'Negros Oriental',
    location: '9.1911,123.2655',
  ),
  NegrosPlace(
    id: 22,
    placeName: 'Valencia',
    province: 'Negros Oriental',
    location: '9.2817,123.2446',
  ),
  NegrosPlace(
    id: 23,
    placeName: 'Sibulan',
    province: 'Negros Oriental',
    location: '9.3667,123.2833',
  ),
  NegrosPlace(
    id: 24,
    placeName: 'Amlan',
    province: 'Negros Oriental',
    location: '9.4636,123.2266',
  ),
  NegrosPlace(
    id: 25,
    placeName: 'Ayungon',
    province: 'Negros Oriental',
    location: '9.8587,123.1436',
  ),
  NegrosPlace(
    id: 26,
    placeName: 'San Jose',
    province: 'Negros Oriental',
    location: '9.4138,123.2417',
  ),
];

final ValueNotifier<List<NegrosPlace>> appNegrosPlacesNotifier =
    ValueNotifier<List<NegrosPlace>>(
      List<NegrosPlace>.from(_fallbackNegrosPlaces),
    );

Future<void> loadNegrosPlaces() async {
  try {
    final List<dynamic> response = await Supabase.instance.client
        .from('negros_places')
        .select()
        .order('province')
        .order('place_name');

    final List<NegrosPlace> loadedPlaces = response
        .map(
          (item) => NegrosPlace.fromMap(Map<String, dynamic>.from(item as Map)),
        )
        .toList();

    if (loadedPlaces.isNotEmpty) {
      appNegrosPlacesNotifier.value = loadedPlaces;
    }
  } catch (_) {
    appNegrosPlacesNotifier.value = List<NegrosPlace>.from(
      _fallbackNegrosPlaces,
    );
  }
}

class NegrosPlacesDatasource {
  Future<List<PlaceModel>> searchPlaces(String query) async {
    final String normalizedQuery = query.trim().toLowerCase();
    final Iterable<NegrosPlace> places = appNegrosPlacesNotifier.value.where((
      place,
    ) {
      if (normalizedQuery.isEmpty) {
        return true;
      }

      return place.placeName.toLowerCase().contains(normalizedQuery) ||
          place.province.toLowerCase().contains(normalizedQuery);
    });

    return places
        .map(
          (place) => PlaceModel(id: place.id.toString(), name: place.placeName),
        )
        .toList();
  }
}
