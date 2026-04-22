import 'package:geolocator/geolocator.dart';

import '../../shared/models/location_point.dart';

class LocationService {
  Future<LocationPoint?> getCurrentLocation() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition();
    return LocationPoint(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
