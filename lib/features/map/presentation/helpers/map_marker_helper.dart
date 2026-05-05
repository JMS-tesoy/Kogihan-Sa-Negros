import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapMarkerHelper {
  const MapMarkerHelper._();

  static CircleAnnotationOptions buildPropertyMarkerAnnotation({
    required Point geometry,
    required String propertyId,
    required bool isSelected,
  }) {
    final int markerColor = isSelected
        ? const Color(0xFFFFD166).toARGB32()
        : const Color(0xFF60A5FA).toARGB32();

    return CircleAnnotationOptions(
      geometry: geometry,
      circleColor: markerColor,
      circleRadius: isSelected ? 8.5 : 5.8,
      circleStrokeColor: Colors.white.toARGB32(),
      circleStrokeWidth: isSelected ? 2.8 : 1.8,
      circleOpacity: 1.0,
      customData: <String, Object>{'propertyId': propertyId},
    );
  }

  static PointAnnotationOptions buildSelectedPropertyLabelAnnotation({
    required Point geometry,
    required String price,
  }) {
    return PointAnnotationOptions(
      geometry: geometry,
      textField: price,
      textSize: 13.0,
      textColor: Colors.white.toARGB32(),
      textHaloColor: const Color(0xFF2563EB).toARGB32(),
      textHaloWidth: 2.5,
      textOffset: [0.0, -2.4],
    );
  }

  static PolygonAnnotationOptions buildBoundaryAnnotation({
    required List<Position> boundaryPositions,
    required String propertyId,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    return PolygonAnnotationOptions(
      geometry: Polygon(coordinates: [boundaryPositions]),
      fillColor: primaryColor.toARGB32(),
      fillOpacity: isDarkMode ? 0.24 : 0.18,
      fillOutlineColor: const Color(0xFFFFD166).toARGB32(),
      customData: <String, Object>{'propertyId': propertyId},
    );
  }
}
