import '../../shared/models/location_point.dart';

abstract final class CoordinateUtils {
  static bool isValid(LocationPoint point) {
    return point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }
}
