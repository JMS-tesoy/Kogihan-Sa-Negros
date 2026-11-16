import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kogihan_sa_negros/features/home/presentation/helpers/home_filter_helpers.dart';
import 'package:kogihan_sa_negros/features/location/data/datasources/negros_places_datasource.dart';
import 'package:kogihan_sa_negros/features/properties/data/datasources/shared_properties.dart';

void main() {
  const List<NegrosPlace> noPlaces = <NegrosPlace>[];

  test('search matches property titles without case sensitivity', () {
    final List<Property> results = filterHomeProperties(
      availableProperties: <Property>[
        _property(id: '1', title: 'Lot in Bacolod'),
        _property(id: '2', title: 'Beachfront land', location: 'Sagay'),
      ],
      negrosPlaces: noPlaces,
      searchQuery: '  BACOLOD ',
      selectedLocation: null,
      selectedLotSize: null,
      selectedBudget: null,
    );

    expect(results.map((property) => property.id), <String>['1']);
  });

  test('search matches formatted prices by their digits', () {
    final List<Property> results = filterHomeProperties(
      availableProperties: <Property>[
        _property(id: '1', price: '₱1,200,000'),
        _property(id: '2', price: '₱950,000'),
      ],
      negrosPlaces: noPlaces,
      searchQuery: '1200000',
      selectedLocation: null,
      selectedLotSize: null,
      selectedBudget: null,
    );

    expect(results.map((property) => property.id), <String>['1']);
  });

  test('short text queries match word starts, not unrelated substrings', () {
    final List<Property> results = filterHomeProperties(
      availableProperties: <Property>[
        _property(id: '1', title: 'Urban lot'),
        _property(id: '2', title: 'Four bedroom lot'),
        _property(id: '3', title: 'City lot', location: 'Urban village'),
      ],
      negrosPlaces: noPlaces,
      searchQuery: 'ur',
      selectedLocation: null,
      selectedLotSize: null,
      selectedBudget: null,
    );

    expect(results.map((property) => property.id), <String>['1', '3']);
  });

  test('text with digits does not match an unrelated numeric price', () {
    final List<Property> results = filterHomeProperties(
      availableProperties: <Property>[
        _property(id: '1', title: 'Urban 1'),
        _property(id: '2', title: 'Other lot'),
      ],
      negrosPlaces: noPlaces,
      searchQuery: 'urban 1',
      selectedLocation: null,
      selectedLotSize: null,
      selectedBudget: null,
    );

    expect(results.map((property) => property.id), <String>['1']);
  });
}

Property _property({
  required String id,
  String title = 'Land',
  String price = '₱1,200,000',
  String location = 'Bacolod',
}) {
  return Property(
    id: id,
    referenceCode: id,
    title: title,
    location: location,
    price: price,
    priceValue: 1200000,
    size: '500 sqm',
    sizeValue: 500,
    tag: 'Available',
    titleStatus: 'Available',
    description: '',
    imageColor: Colors.green,
  );
}
