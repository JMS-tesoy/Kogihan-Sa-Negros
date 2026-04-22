import '../../../../shared/models/location_point.dart';

class PropertyBoundaryModel {
  const PropertyBoundaryModel({
    required this.points,
  });

  final List<LocationPoint> points;
}
