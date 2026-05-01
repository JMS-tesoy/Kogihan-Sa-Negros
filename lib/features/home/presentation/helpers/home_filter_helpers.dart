import 'dart:math' as math;

import '../../../location/data/datasources/negros_places_datasource.dart';
import '../../../properties/data/datasources/shared_properties.dart';

List<Property> filterHomeProperties({
  required List<Property> availableProperties,
  required List<NegrosPlace> negrosPlaces,
  required String searchQuery,
  required String? selectedLocation,
  required String? selectedLotSize,
  required String? selectedBudget,
}) {
  final String normalizedQuery = normalizeSearchText(searchQuery);
  final String numericQuery = digitsOnly(searchQuery);
  final bool hasSearchQuery =
      normalizedQuery.isNotEmpty || numericQuery.isNotEmpty;
  final bool hasLocationFilter = selectedLocation != null;
  final bool hasLotSizeFilter = selectedLotSize != null;
  final bool hasBudgetFilter = selectedBudget != null;

  if (!hasSearchQuery &&
      !hasLocationFilter &&
      !hasLotSizeFilter &&
      !hasBudgetFilter) {
    return List<Property>.from(availableProperties);
  }

  return availableProperties
      .where((property) {
        if (hasLocationFilter) {
          final NegrosPlace? selectedPlace = negrosPlaces
              .cast<NegrosPlace?>()
              .firstWhere(
                (place) => place?.placeName == selectedLocation,
                orElse: () => null,
              );

          if (selectedPlace != null) {
            final List<double>? propertyCoordinates = parsePropertyCoordinates(
              property.location,
            );
            final double? placeLatitude = selectedPlace.latitude;
            final double? placeLongitude = selectedPlace.longitude;

            if (propertyCoordinates == null ||
                placeLatitude == null ||
                placeLongitude == null) {
              return false;
            }

            final double propertyDistanceInKm = distanceInKm(
              startLatitude: propertyCoordinates[0],
              startLongitude: propertyCoordinates[1],
              endLatitude: placeLatitude,
              endLongitude: placeLongitude,
            );

            if (propertyDistanceInKm > 25) return false;
          } else if (property.location != selectedLocation) {
            return false;
          }
        }

        if (hasLotSizeFilter) {
          final bool matchesLotSize = switch (selectedLotSize) {
            'Below 500 sqm' => property.sizeValue < 500,
            '500 - 1000 sqm' =>
              property.sizeValue >= 500 && property.sizeValue <= 1000,
            'Above 1000 sqm' => property.sizeValue > 1000,
            _ => true,
          };

          if (!matchesLotSize) return false;
        }

        if (hasBudgetFilter) {
          final bool matchesBudget = switch (selectedBudget) {
            'Below ₱1M' => property.priceValue < 1000000,
            '₱1M - ₱3M' =>
              property.priceValue >= 1000000 && property.priceValue <= 3000000,
            'Above ₱3M' => property.priceValue > 3000000,
            _ => true,
          };

          if (!matchesBudget) return false;
        }

        if (!hasSearchQuery) return true;

        final String normalizedTitle = normalizeSearchText(property.title);
        final String normalizedLocation = normalizeSearchText(
          property.location,
        );
        final String normalizedPrice = normalizeSearchText(property.price);

        if (normalizedTitle.contains(normalizedQuery) ||
            normalizedLocation.contains(normalizedQuery) ||
            normalizedPrice.contains(normalizedQuery)) {
          return true;
        }

        if (numericQuery.isEmpty) return false;

        final String numericPrice = digitsOnly(property.price);
        return numericPrice.contains(numericQuery);
      })
      .toList(growable: false);
}

List<String> homeLocationFilterItems(List<NegrosPlace> negrosPlaces) {
  return negrosPlaces.map((place) => place.placeName).toSet().toList()..sort();
}

List<double>? parsePropertyCoordinates(String value) {
  final List<String> parts = value.split(',');
  if (parts.length < 2) return null;

  final double? latitude = double.tryParse(parts[0].trim());
  final double? longitude = double.tryParse(parts[1].trim());
  if (latitude == null || longitude == null) return null;

  return <double>[latitude, longitude];
}

double distanceInKm({
  required double startLatitude,
  required double startLongitude,
  required double endLatitude,
  required double endLongitude,
}) {
  const double earthRadiusKm = 6371;
  final double latitudeDelta = degreesToRadians(endLatitude - startLatitude);
  final double longitudeDelta = degreesToRadians(endLongitude - startLongitude);
  final double a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(degreesToRadians(startLatitude)) *
          math.cos(degreesToRadians(endLatitude)) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double degreesToRadians(double degrees) => degrees * (math.pi / 180);

String normalizeSearchText(String value) {
  return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
}

String digitsOnly(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}
