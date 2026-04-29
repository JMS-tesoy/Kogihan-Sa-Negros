import 'dart:math' as math;

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
  final double longitudeDelta = degreesToRadians(
    endLongitude - startLongitude,
  );
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
