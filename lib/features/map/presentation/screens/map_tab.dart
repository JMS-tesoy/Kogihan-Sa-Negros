import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide ImageSource, Size;

import '../../../../app/config/app_config.dart';
import '../../../../app/config/mapbox_config.dart';
import '../../../../app/router/instant_route.dart';
import '../../../location/data/datasources/negros_places_datasource.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import '../../../properties/presentation/screens/property_details_screen.dart';
import '../../../properties/presentation/widgets/property_image.dart';

const int _initialMapAnnotationBatchSize = 8;
const int _mapAnnotationBatchSize = 12;
const int _maxMapPrecachedThumbnails = 4;
const double _mapAutoCardMinZoom = 13.25;
const double _mapAutoCardFullZoom = 18.0;
const double _mapAutoCardMinScale = 0.52;
const double _mapAutoCardPixelRadius = 112.0;
final Point _negrosIslandCenter = Point(coordinates: Position(123.02, 10.1));
const double _negrosIslandInitialZoom = 7.35;
const String _mapTerrainSourceId = 'property-terrain-dem';

enum _MapLightPreset { day, night }

enum _MapStyleMode { monochrome, satellite }

class _MappableProperty {
  final Property property;
  final double latitude;
  final double longitude;

  const _MappableProperty({
    required this.property,
    required this.latitude,
    required this.longitude,
  });

  Point get point => Point(coordinates: Position(longitude, latitude));
}

_MappableProperty? _mappablePropertyFromProperty(Property property) {
  final List<double>? boundaryCenter = _boundaryCenterFromText(
    property.boundaryCoordinates,
  );
  final List<double>? coordinatePair =
      boundaryCenter ?? _coordinatePairFromText(property.location);
  if (coordinatePair == null) return null;

  return _MappableProperty(
    property: property,
    latitude: coordinatePair[0],
    longitude: coordinatePair[1],
  );
}

List<_MappableProperty> _extractMappableProperties(
  Iterable<Property> properties,
) {
  return properties
      .map(_mappablePropertyFromProperty)
      .whereType<_MappableProperty>()
      .toList(growable: false);
}

List<double>? _coordinatePairFromText(String value) {
  final List<List<double>> coordinatePairs = _coordinatePairsFromText(value);
  return coordinatePairs.length == 1 ? coordinatePairs.first : null;
}

List<List<double>> _coordinatePairsFromText(String value) {
  final String normalized = value.trim().toUpperCase();
  if (normalized.isEmpty) return const <List<double>>[];

  if (RegExp(r'''['"′″]''').hasMatch(normalized)) {
    return const <List<double>>[];
  }
  final List<RegExpMatch> matches = RegExp(
    r'([-+]?\d+(?:\.\d+)?)\s*°?\s*([NSEW])?',
  ).allMatches(normalized).toList(growable: false);
  if (matches.length < 2) return const <List<double>>[];

  final List<List<double>> coordinatePairs = <List<double>>[];
  for (int index = 0; index + 1 < matches.length; index += 2) {
    double? latitude = double.tryParse(matches[index].group(1)!);
    double? longitude = double.tryParse(matches[index + 1].group(1)!);
    if (latitude == null || longitude == null) continue;

    final String? latitudeDirection = matches[index].group(2);
    final String? longitudeDirection = matches[index + 1].group(2);
    if (latitudeDirection == 'S') latitude = -latitude.abs();
    if (longitudeDirection == 'W') longitude = -longitude.abs();

    if (latitude < -90 || latitude > 90) continue;
    if (longitude < -180 || longitude > 180) continue;

    coordinatePairs.add(<double>[latitude, longitude]);
  }

  return coordinatePairs;
}

List<Position>? _boundaryPositionsFromText(String? rawValue) {
  final String normalized = (rawValue ?? '').trim();
  if (normalized.isEmpty) return null;

  final List<Position> positions = <Position>[];
  for (final List<double> coordinatePair in _coordinatePairsFromText(
    normalized,
  )) {
    positions.add(Position(coordinatePair[1], coordinatePair[0]));
  }

  if (positions.length < 3) return null;

  final Position first = positions.first;
  final Position last = positions.last;
  if (first.lng != last.lng || first.lat != last.lat) {
    positions.add(Position(first.lng, first.lat));
  }

  return positions.length >= 4 ? positions : null;
}

List<double>? _boundaryCenterFromText(String? rawValue) {
  final List<Position>? boundaryPositions = _boundaryPositionsFromText(
    rawValue,
  );
  if (boundaryPositions == null) return null;

  final List<Position> uniquePositions = List<Position>.from(boundaryPositions);
  if (uniquePositions.length > 1) {
    uniquePositions.removeLast();
  }
  if (uniquePositions.isEmpty) return null;

  double latitudeTotal = 0;
  double longitudeTotal = 0;
  for (final Position position in uniquePositions) {
    longitudeTotal += position.lng.toDouble();
    latitudeTotal += position.lat.toDouble();
  }

  return <double>[
    latitudeTotal / uniquePositions.length,
    longitudeTotal / uniquePositions.length,
  ];
}

class MapTab extends StatefulWidget {
  final Set<Property> savedProperties;
  final ValueChanged<Property> onToggleSave;
  final String? initialSelectedPropertyId;

  const MapTab({
    super.key,
    required this.savedProperties,
    required this.onToggleSave,
    this.initialSelectedPropertyId,
  });

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  List<_MappableProperty> _mappableProperties = _extractMappableProperties(
    appPropertiesNotifier.value,
  );
  List<NegrosPlace> _negrosPlaces = List<NegrosPlace>.from(
    appNegrosPlacesNotifier.value,
  );
  final Set<String> _warmedMapPropertyImageIds = <String>{};

  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  PolygonAnnotationManager? _boundaryAnnotationManager;
  PolylineAnnotationManager? _routeAnnotationManager;
  Cancelable? _annotationTapCancelable;

  int _annotationSyncVersion = 0;
  int _elevationRequestVersion = 0;
  bool _hasFittedCamera = false;
  bool _isLoadingElevation = false;
  bool _isPropertyPickerVisible = false;
  bool _isSelectedCardVisible = true;
  bool _shouldShowCardAfterUserZoom = false;
  double _selectedCardScale = 1.0;
  double? _selectedElevationMeters;
  String? _selectedPropertyId;
  ViewportState? _mapViewport;
  _MapStyleMode _selectedMapStyleMode = _MapStyleMode.satellite;
  String _currentStyleUri = MapboxStyles.STANDARD_SATELLITE;
  _MapLightPreset _selectedLightPreset = _MapLightPreset.day;

  // NEW: price label annotation manager and location puck toggle
  PointAnnotationManager? _labelAnnotationManager;
  bool _isLocationEnabled = false;

  @override
  void initState() {
    super.initState();
    _selectedPropertyId = widget.initialSelectedPropertyId;
    final _MappableProperty? initialSelected = _selectedMappedProperty;
    if (initialSelected != null) {
      _isSelectedCardVisible =
          _boundaryPositionsFromText(
            initialSelected.property.boundaryCoordinates,
          ) ==
          null;
    }
    appPropertiesNotifier.addListener(_handlePropertiesChanged);
    appNegrosPlacesNotifier.addListener(_handleNegrosPlacesChanged);
    _warmMapPropertyImages(
      _mappableProperties.take(AppConfig.initialPropertyImagePrefetchCount),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final Brightness brightness = Theme.of(context).brightness;
    final String nextStyleUri = _styleUriForMode(_selectedMapStyleMode);
    final _MapLightPreset nextLightPreset = _lightPresetForBrightness(
      brightness,
    );

    final bool lightPresetChanged = _selectedLightPreset != nextLightPreset;
    _selectedLightPreset = nextLightPreset;

    if (_currentStyleUri == nextStyleUri) {
      final MapboxMap? mapboxMap = _mapboxMap;
      if (lightPresetChanged && mapboxMap != null) {
        unawaited(_applyStandardStyleConfiguration(mapboxMap));
      }
      return;
    }

    _reloadMapStyle(nextStyleUri);
  }

  @override
  void dispose() {
    appPropertiesNotifier.removeListener(_handlePropertiesChanged);
    appNegrosPlacesNotifier.removeListener(_handleNegrosPlacesChanged);
    _annotationTapCancelable?.cancel();

    final MapboxMap? mapboxMap = _mapboxMap;
    final CircleAnnotationManager? annotationManager = _circleAnnotationManager;
    if (mapboxMap != null && annotationManager != null) {
      unawaited(
        mapboxMap.annotations.removeAnnotationManager(annotationManager),
      );
    }
    final PolygonAnnotationManager? boundaryAnnotationManager =
        _boundaryAnnotationManager;
    if (mapboxMap != null && boundaryAnnotationManager != null) {
      unawaited(
        mapboxMap.annotations.removeAnnotationManager(
          boundaryAnnotationManager,
        ),
      );
    }
    final PolylineAnnotationManager? routeAnnotationManager =
        _routeAnnotationManager;
    if (mapboxMap != null && routeAnnotationManager != null) {
      unawaited(
        mapboxMap.annotations.removeAnnotationManager(routeAnnotationManager),
      );
    }
    // NEW: clean up label annotation manager
    final PointAnnotationManager? labelAnnotationManager =
        _labelAnnotationManager;
    if (mapboxMap != null && labelAnnotationManager != null) {
      unawaited(
        mapboxMap.annotations.removeAnnotationManager(labelAnnotationManager),
      );
    }

    super.dispose();
  }

  void _handlePropertiesChanged() {
    final List<_MappableProperty> nextProperties = _extractMappableProperties(
      appPropertiesNotifier.value,
    );
    final bool selectedPropertyRemoved =
        _selectedPropertyId != null &&
        nextProperties.every((item) => item.property.id != _selectedPropertyId);

    if (!mounted) return;

    setState(() {
      _mappableProperties = nextProperties;
      if (selectedPropertyRemoved) {
        _selectedPropertyId = null;
        _isSelectedCardVisible = true;
        _selectedCardScale = 1.0;
        _selectedElevationMeters = null;
        _isLoadingElevation = false;
        _elevationRequestVersion++;
      }
    });

    _warmMapPropertyImages(
      nextProperties.take(AppConfig.initialPropertyImagePrefetchCount),
    );
    unawaited(_syncSelectedBoundary());
    unawaited(_syncSelectedLabel()); // NEW
    if (selectedPropertyRemoved) {
      unawaited(_clearRoutePolyline());
    }
    unawaited(_syncAnnotations(resetCamera: false));
  }

  void _handleNegrosPlacesChanged() {
    if (!mounted) return;
    setState(() {
      _negrosPlaces = List<NegrosPlace>.from(appNegrosPlacesNotifier.value);
    });
  }

  void _warmMapPropertyImages(Iterable<_MappableProperty> properties) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final _MappableProperty item in properties.take(
        _maxMapPrecachedThumbnails,
      )) {
        if (_warmedMapPropertyImageIds.add(item.property.id)) {
          warmPropertyImage(context, item.property, useThumbnail: true);
        }
      }
    });
  }

  String _styleUriForMode(_MapStyleMode mode) {
    switch (mode) {
      case _MapStyleMode.monochrome:
        return MapboxStyles.STANDARD;
      case _MapStyleMode.satellite:
        return MapboxStyles.STANDARD_SATELLITE;
    }
  }

  void _reloadMapStyle(String nextStyleUri) {
    _annotationTapCancelable?.cancel();
    _annotationTapCancelable = null;
    _mapboxMap = null;
    _circleAnnotationManager = null;
    _boundaryAnnotationManager = null;
    _routeAnnotationManager = null;
    _labelAnnotationManager = null; // NEW: reset label manager on style change
    _hasFittedCamera = false;
    _currentStyleUri = nextStyleUri;
  }

  void _setMapStyleMode(_MapStyleMode mode) {
    if (_selectedMapStyleMode == mode) return;

    setState(() {
      _selectedMapStyleMode = mode;
      _reloadMapStyle(_styleUriForMode(mode));
    });
  }

  Future<void> _toggleMapStyleMode() {
    final _MapStyleMode nextMode =
        _selectedMapStyleMode == _MapStyleMode.monochrome
        ? _MapStyleMode.satellite
        : _MapStyleMode.monochrome;

    _setMapStyleMode(nextMode);
    return Future<void>.value();
  }

  double _cardScaleForZoom(double zoom) {
    final double progress =
        ((zoom - _mapAutoCardMinZoom) /
                (_mapAutoCardFullZoom - _mapAutoCardMinZoom))
            .clamp(0.0, 1.0)
            .toDouble();
    return _mapAutoCardMinScale + ((1.0 - _mapAutoCardMinScale) * progress);
  }

  _MapLightPreset _lightPresetForBrightness(Brightness brightness) {
    return brightness == Brightness.dark
        ? _MapLightPreset.night
        : _MapLightPreset.day;
  }

  Future<void> _setStandardStyleConfig(
    MapboxMap mapboxMap,
    String name,
    Object value,
  ) async {
    try {
      await mapboxMap.style.setStyleImportConfigProperty(
        'basemap',
        name,
        value,
      );
    } catch (_) {
      // Some Mapbox SDK/style versions do not expose every standard config.
    }
  }

  Future<void> _applyStandardStyleConfiguration(MapboxMap mapboxMap) async {
    await _setStandardStyleConfig(
      mapboxMap,
      'lightPreset',
      _selectedLightPreset.name,
    );

    if (_selectedMapStyleMode == _MapStyleMode.monochrome) {
      await _setStandardStyleConfig(mapboxMap, 'theme', 'monochrome');
      await _setStandardStyleConfig(mapboxMap, 'show3dObjects', false);
      await _setStandardStyleConfig(
        mapboxMap,
        'showPointOfInterestLabels',
        true,
      );
      await _setStandardStyleConfig(mapboxMap, 'showTransitLabels', false);
    }
  }

  Future<void> _enableTerrainForElevation(MapboxMap mapboxMap) async {
    try {
      final bool hasTerrainSource = await mapboxMap.style.styleSourceExists(
        _mapTerrainSourceId,
      );
      if (!hasTerrainSource) {
        await mapboxMap.style.addSource(
          RasterDemSource(
            id: _mapTerrainSourceId,
            url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
            tileSize: 512,
            maxzoom: 14,
          ),
        );
      }
      await mapboxMap.style.setStyleTerrain(
        '{"source":"$_mapTerrainSourceId","exaggeration":1}',
      );
    } catch (_) {
      // Elevation is best-effort; the map should still work without terrain.
    }
  }

  PolygonAnnotationOptions? _buildBoundaryAnnotation(Property property) {
    final List<Position>? boundaryPositions = _boundaryPositionsFromText(
      property.boundaryCoordinates,
    );
    if (boundaryPositions == null) return null;

    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color fillColor = isDarkMode
        ? const Color(0xFF38BDF8)
        : Theme.of(context).colorScheme.primary;

    return PolygonAnnotationOptions(
      geometry: Polygon(coordinates: [boundaryPositions]),
      fillColor: fillColor.toARGB32(),
      fillOpacity: isDarkMode ? 0.24 : 0.18,
      fillOutlineColor: const Color(0xFFFFD166).toARGB32(),
      customData: <String, Object>{'propertyId': property.id},
    );
  }

  Future<void> _syncSelectedBoundary() async {
    final PolygonAnnotationManager? annotationManager =
        _boundaryAnnotationManager;
    if (annotationManager == null) return;

    await annotationManager.deleteAll();
    if (!mounted) return;

    final _MappableProperty? selected = _selectedMappedProperty;
    if (selected == null) return;

    final PolygonAnnotationOptions? boundaryAnnotation =
        _buildBoundaryAnnotation(selected.property);
    if (boundaryAnnotation == null) return;

    await annotationManager.create(boundaryAnnotation);
  }

  // NEW: syncs the floating price label annotation for the selected property
  Future<void> _syncSelectedLabel() async {
    final PointAnnotationManager? labelManager = _labelAnnotationManager;
    if (labelManager == null) return;

    await labelManager.deleteAll();
    if (!mounted) return;

    final _MappableProperty? selected = _selectedMappedProperty;
    if (selected == null) return;

    await labelManager.create(
      PointAnnotationOptions(
        geometry: selected.point,
        textField: selected.property.price,
        textSize: 13.0,
        textColor: Colors.white.toARGB32(),
        textHaloColor: selected.property.imageColor.toARGB32(),
        textHaloWidth: 2.5,
        textOffset: [0.0, -2.4],
      ),
    );
  }

  Future<void> _clearRoutePolyline() async {
    final PolylineAnnotationManager? routeManager = _routeAnnotationManager;
    if (routeManager == null) return;

    await routeManager.deleteAll();
  }

  void _showMapMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _promptEnableGpsLocation() async {
    if (!mounted) return;

    final bool? shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Enable GPS location'),
          content: const Text(
            'Turn on device location to show your position on the map.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open settings'),
            ),
          ],
        );
      },
    );

    if (shouldOpenSettings == true) {
      await geo.Geolocator.openLocationSettings();
    }
  }

  Future<void> _promptOpenLocationPermissionSettings() async {
    if (!mounted) return;

    final bool? shouldOpenSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Allow location access'),
          content: const Text(
            'Location permission is needed to show your position on the map.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Open settings'),
            ),
          ],
        );
      },
    );

    if (shouldOpenSettings == true) {
      await geo.Geolocator.openAppSettings();
    }
  }

  Future<bool> _ensureGpsLocationReady() async {
    final bool isServiceEnabled =
        await geo.Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      await _promptEnableGpsLocation();
      return false;
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.deniedForever) {
      await _promptOpenLocationPermissionSettings();
      return false;
    }

    if (permission == geo.LocationPermission.denied) {
      _showMapMessage('Location permission is needed to show your position.');
      return false;
    }

    return true;
  }

  // NEW: gets device GPS, centers the map, and enables Mapbox location puck
  Future<void> _toggleMyLocation() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;
    final int pulsingColor = Theme.of(context).colorScheme.primary.toARGB32();

    final bool isLocationReady = await _ensureGpsLocationReady();
    if (!isLocationReady) return;

    final geo.Position position;
    try {
      position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
    } catch (_) {
      _showMapMessage('Unable to get your current location.');
      return;
    }

    await mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: pulsingColor,
        puckBearingEnabled: true,
        puckBearing: PuckBearing.HEADING,
      ),
    );
    await mapboxMap.easeTo(
      CameraOptions(
        center: Point(
          coordinates: Position(position.longitude, position.latitude),
        ),
        zoom: 16.0,
        pitch: 0,
      ),
      MapAnimationOptions(duration: 700),
    );

    if (!mounted) return;
    setState(() {
      _isLocationEnabled = true;
      _mapViewport = FollowPuckViewportState(
        zoom: 16.0,
        pitch: 0,
        bearing: const FollowPuckViewportStateBearingHeading(),
        padding: MbxEdgeInsets(top: 80, left: 0, bottom: 120, right: 0),
      );
    });
  }

  Future<List<Position>?> _fetchRoutePositions({
    required geo.Position origin,
    required _MappableProperty destination,
  }) async {
    final Uri uri = Uri.https(
      'api.mapbox.com',
      '/directions/v5/mapbox/driving/'
          '${origin.longitude},${origin.latitude};'
          '${destination.longitude},${destination.latitude}',
      <String, String>{
        'alternatives': 'false',
        'geometries': 'geojson',
        'overview': 'full',
        'steps': 'false',
        'access_token': MapboxConfig.accessToken,
      },
    );

    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      final HttpClientResponse response = await request.close();
      if (response.statusCode != HttpStatus.ok) return null;

      final String body = await utf8.decodeStream(response);
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;

      final Object? routesValue = decoded['routes'];
      if (routesValue is! List || routesValue.isEmpty) return null;

      final Object? routeValue = routesValue.first;
      if (routeValue is! Map<String, dynamic>) return null;

      final Object? geometryValue = routeValue['geometry'];
      if (geometryValue is! Map<String, dynamic>) return null;

      final Object? coordinatesValue = geometryValue['coordinates'];
      if (coordinatesValue is! List) return null;

      final List<Position> positions = <Position>[];
      for (final Object? coordinate in coordinatesValue) {
        if (coordinate is! List || coordinate.length < 2) continue;

        final Object? longitudeValue = coordinate[0];
        final Object? latitudeValue = coordinate[1];
        if (longitudeValue is! num || latitudeValue is! num) continue;

        positions.add(
          Position(longitudeValue.toDouble(), latitudeValue.toDouble()),
        );
      }

      return positions.length >= 2 ? positions : null;
    } catch (error, stackTrace) {
      developer.log(
        'Unable to fetch Mapbox route',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _showRouteToSelectedProperty() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    final _MappableProperty? selected = _selectedMappedProperty;
    if (selected == null) {
      _showMapMessage('Select a property first.');
      return;
    }

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final int pulsingColor = colorScheme.primary.toARGB32();
    final int routeColor = const Color(0xFF38BDF8).toARGB32();
    final int routeBorderColor = Colors.white
        .withValues(alpha: 0.72)
        .toARGB32();

    final bool isLocationReady = await _ensureGpsLocationReady();
    if (!isLocationReady) return;

    final geo.Position position;
    try {
      position = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
        ),
      );
    } catch (_) {
      _showMapMessage('Unable to get your current location.');
      return;
    }

    final List<Position>? routePositions = await _fetchRoutePositions(
      origin: position,
      destination: selected,
    );
    if (routePositions == null) {
      _showMapMessage('Unable to find a route to this property.');
      return;
    }

    if (!mounted ||
        _mapboxMap != mapboxMap ||
        _selectedPropertyId != selected.property.id) {
      return;
    }

    await mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: true,
        pulsingColor: pulsingColor,
        puckBearingEnabled: true,
        puckBearing: PuckBearing.HEADING,
      ),
    );

    PolylineAnnotationManager? routeManager = _routeAnnotationManager;
    if (routeManager == null) {
      routeManager = await mapboxMap.annotations
          .createPolylineAnnotationManager(id: 'property-route');
      _routeAnnotationManager = routeManager;
    }

    await routeManager.deleteAll();
    await routeManager.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: routePositions),
        lineBorderColor: routeBorderColor,
        lineBorderWidth: 1.5,
        lineColor: routeColor,
        lineEmissiveStrength: 0.75,
        lineJoin: LineJoin.ROUND,
        lineOpacity: 0.88,
        lineWidth: 5.5,
        lineZOffset: 2.0,
      ),
    );

    final List<Point> cameraPoints = routePositions
        .map((position) => Point(coordinates: position))
        .toList(growable: false);
    final CameraOptions camera = await mapboxMap.cameraForCoordinatesPadding(
      cameraPoints,
      CameraOptions(),
      MbxEdgeInsets(top: 96, left: 36, bottom: 132, right: 36),
      16.5,
      null,
    );

    if (!mounted) return;
    setState(() {
      _isLocationEnabled = true;
      _mapViewport = null;
    });
    await mapboxMap.easeTo(camera, MapAnimationOptions(duration: 700));
  }

  // NEW: fits camera to show all listed property markers at once
  Future<void> _fitCameraToAllProperties() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    if (_mappableProperties.isEmpty) {
      await _fitCameraToNegrosPlaces();
      return;
    }

    final List<Point> propertyPoints = _mappableProperties
        .map((item) => item.point)
        .toList(growable: false);

    final CameraOptions camera = await mapboxMap.cameraForCoordinatesPadding(
      propertyPoints,
      CameraOptions(),
      MbxEdgeInsets(top: 80, left: 36, bottom: 80, right: 36),
      14.0,
      null,
    );
    await mapboxMap.easeTo(camera, MapAnimationOptions(duration: 700));
  }

  void _togglePropertyPickerFromBadge() {
    if (_mappableProperties.isEmpty) return;

    setState(() {
      _isPropertyPickerVisible = !_isPropertyPickerVisible;
    });
  }

  void _selectAvailablePropertyFromBadge(_MappableProperty selected) {
    final bool selectedPropertyChanged =
        _selectedPropertyId != selected.property.id;

    setState(() {
      _selectedPropertyId = selected.property.id;
      _isPropertyPickerVisible = false;
      _isSelectedCardVisible = true;
      _selectedCardScale = 1.0;
    });

    _warmMapPropertyImages([selected]);
    if (selectedPropertyChanged) {
      unawaited(_clearRoutePolyline());
    }
    unawaited(_syncSelectedBoundary());
    unawaited(_syncSelectedLabel());
    unawaited(_syncAnnotations(resetCamera: false));
    unawaited(_focusOnSelectedPropertyBoundary(selected));
    unawaited(_updateSelectedElevation(selected));
  }

  void _clearSelectedElevation() {
    _elevationRequestVersion++;
    _selectedElevationMeters = null;
    _isLoadingElevation = false;
  }

  Future<void> _updateSelectedElevation(_MappableProperty selected) async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    final int requestVersion = ++_elevationRequestVersion;
    if (mounted) {
      setState(() {
        _selectedElevationMeters = null;
        _isLoadingElevation = true;
      });
    }

    await Future<void>.delayed(const Duration(milliseconds: 720));
    if (!mounted ||
        requestVersion != _elevationRequestVersion ||
        _selectedPropertyId != selected.property.id) {
      return;
    }

    double? elevationMeters;
    try {
      elevationMeters = await mapboxMap.getElevation(selected.point);
    } catch (_) {
      elevationMeters = null;
    }

    if (!mounted ||
        requestVersion != _elevationRequestVersion ||
        _selectedPropertyId != selected.property.id) {
      return;
    }

    setState(() {
      _selectedElevationMeters = elevationMeters;
      _isLoadingElevation = false;
    });
  }

  List<Point> _negrosPlacePoints() {
    return _negrosPlaces
        .where((place) => place.latitude != null && place.longitude != null)
        .map(
          (place) =>
              Point(coordinates: Position(place.longitude!, place.latitude!)),
        )
        .toList(growable: false);
  }

  Map<String, List<NegrosPlace>> _groupNegrosPlacesByProvince() {
    final Map<String, List<NegrosPlace>> groupedPlaces =
        <String, List<NegrosPlace>>{};

    for (final NegrosPlace place in _negrosPlaces) {
      final String province = place.province.trim().isEmpty
          ? 'Other Areas'
          : place.province.trim();
      groupedPlaces.putIfAbsent(province, () => <NegrosPlace>[]).add(place);
    }

    for (final List<NegrosPlace> places in groupedPlaces.values) {
      places.sort(
        (first, second) => first.placeName.compareTo(second.placeName),
      );
    }

    return groupedPlaces;
  }

  Future<void> _focusOnNegrosPlace(NegrosPlace place) async {
    final double? latitude = place.latitude;
    final double? longitude = place.longitude;
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null || latitude == null || longitude == null) return;

    if (mounted) {
      setState(() {
        _selectedPropertyId = null;
        _isSelectedCardVisible = true;
        _selectedCardScale = 1.0;
        _clearSelectedElevation();
      });
    }
    unawaited(_syncSelectedBoundary());
    unawaited(_clearRoutePolyline());

    await mapboxMap.easeTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: 11.8,
      ),
      MapAnimationOptions(duration: 650),
    );
  }

  Future<void> _fitCameraToNegrosPlaces() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    final List<Point> placePoints = _negrosPlacePoints();
    if (mapboxMap == null) return;

    if (placePoints.isEmpty) {
      await mapboxMap.easeTo(
        CameraOptions(
          center: _negrosIslandCenter,
          zoom: _negrosIslandInitialZoom,
        ),
        MapAnimationOptions(duration: 700),
      );
      return;
    }

    final CameraOptions camera = await mapboxMap.cameraForCoordinatesPadding(
      placePoints,
      CameraOptions(),
      MbxEdgeInsets(top: 96, left: 36, bottom: 96, right: 36),
      7.9,
      null,
    );
    await mapboxMap.easeTo(camera, MapAnimationOptions(duration: 700));
  }

  Future<void> _openNegrosPlacesSheet() async {
    final NegrosPlace? selectedPlace = await showModalBottomSheet<NegrosPlace>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      requestFocus: false,
      builder: (sheetContext) {
        return _NegrosPlacesSheet(
          groupedPlaces: _groupNegrosPlacesByProvince(),
        );
      },
    );

    if (!mounted || selectedPlace == null) return;
    await _focusOnNegrosPlace(selectedPlace);
  }

  Future<void> _zoomIn() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;
    await mapboxMap.scaleBy(2.0, null, MapAnimationOptions(duration: 220));
  }

  Future<void> _zoomOut() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;
    await mapboxMap.scaleBy(0.5, null, MapAnimationOptions(duration: 220));
  }

  Future<void> _resetNorth() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;
    final CameraState cameraState = await mapboxMap.getCameraState();
    await mapboxMap.easeTo(
      CameraOptions(
        center: cameraState.center,
        zoom: cameraState.zoom,
        bearing: 0,
        pitch: 0,
      ),
      MapAnimationOptions(duration: 260),
    );
  }

  _MappableProperty? get _selectedMappedProperty {
    for (final _MappableProperty item in _mappableProperties) {
      if (item.property.id == _selectedPropertyId) return item;
    }
    return null;
  }

  CircleAnnotationOptions _buildAnnotation(_MappableProperty item) {
    final bool isSelected = item.property.id == _selectedPropertyId;

    return CircleAnnotationOptions(
      geometry: item.point,
      circleColor: item.property.imageColor.toARGB32(),
      circleRadius: isSelected ? 8.0 : 5.0,
      circleStrokeColor: isSelected
          ? const Color(0xFFFFD166).toARGB32()
          : Colors.white.toARGB32(),
      circleStrokeWidth: isSelected ? 2.5 : 1.5,
      circleOpacity: 1.0,
      customData: <String, Object>{'propertyId': item.property.id},
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false));
    await mapboxMap.gestures.updateSettings(
      GesturesSettings(
        pinchToZoomEnabled: true,
        pinchPanEnabled: true,
        scrollEnabled: true,
        doubleTapToZoomInEnabled: true,
        doubleTouchToZoomOutEnabled: true,
        quickZoomEnabled: true,
      ),
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    await _applyStandardStyleConfiguration(mapboxMap);
    await _enableTerrainForElevation(mapboxMap);

    _annotationTapCancelable?.cancel();
    final PolygonAnnotationManager? existingBoundaryManager =
        _boundaryAnnotationManager;
    if (existingBoundaryManager != null) {
      unawaited(
        mapboxMap.annotations.removeAnnotationManager(existingBoundaryManager),
      );
    }
    final CircleAnnotationManager? existingManager = _circleAnnotationManager;
    if (existingManager != null) {
      unawaited(mapboxMap.annotations.removeAnnotationManager(existingManager));
    }

    _boundaryAnnotationManager = await mapboxMap.annotations
        .createPolygonAnnotationManager(id: 'property-boundary');
    final CircleAnnotationManager annotationManager = await mapboxMap
        .annotations
        .createCircleAnnotationManager(id: 'property-markers');
    _circleAnnotationManager = annotationManager;

    // NEW: create label manager after circle manager so text renders on top
    _labelAnnotationManager = await mapboxMap.annotations
        .createPointAnnotationManager(id: 'property-price-labels');

    _annotationTapCancelable = annotationManager.tapEvents(
      onTap: _handleAnnotationTap,
    );

    await _syncAnnotations(resetCamera: true);
    await _syncSelectedBoundary();
    await _syncSelectedLabel(); // NEW
    final _MappableProperty? selected = _selectedMappedProperty;
    if (selected != null) {
      unawaited(_focusOnSelectedPropertyBoundary(selected));
      unawaited(_updateSelectedElevation(selected));
    }
  }

  void _handleAnnotationTap(CircleAnnotation annotation) {
    final String? propertyId = annotation.customData?['propertyId'] as String?;
    if (propertyId == null) return;

    final _MappableProperty? selected = _mappableProperties
        .cast<_MappableProperty?>()
        .firstWhere(
          (item) => item?.property.id == propertyId,
          orElse: () => null,
        );
    if (selected == null) return;

    final bool hasBoundary =
        _boundaryPositionsFromText(selected.property.boundaryCoordinates) !=
        null;
    final bool selectedPropertyChanged = _selectedPropertyId != propertyId;
    setState(() {
      _selectedPropertyId = propertyId;
      _isSelectedCardVisible = !hasBoundary;
      _selectedCardScale = 1.0;
    });

    _warmMapPropertyImages([selected]);
    if (selectedPropertyChanged) {
      unawaited(_clearRoutePolyline());
    }
    unawaited(_syncSelectedBoundary());
    unawaited(_syncSelectedLabel()); // NEW
    unawaited(_syncAnnotations(resetCamera: false));
    unawaited(_focusOnSelectedPropertyBoundary(selected));
    unawaited(_updateSelectedElevation(selected));
  }

  Future<void> _focusOnSelectedPropertyBoundary(
    _MappableProperty selected,
  ) async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    final List<Position>? boundaryPositions = _boundaryPositionsFromText(
      selected.property.boundaryCoordinates,
    );
    if (boundaryPositions == null) {
      await mapboxMap.easeTo(
        CameraOptions(center: selected.point, zoom: 15.0),
        MapAnimationOptions(duration: 650),
      );
      return;
    }

    final List<Point> boundaryPoints = boundaryPositions
        .map((position) => Point(coordinates: position))
        .toList(growable: false);
    final CameraOptions camera = await mapboxMap.cameraForCoordinatesPadding(
      boundaryPoints,
      CameraOptions(),
      MbxEdgeInsets(top: 96, left: 36, bottom: 132, right: 36),
      // FIX: cap zoom at 17.5 in satellite mode to prevent blurry imagery
      _selectedMapStyleMode == _MapStyleMode.satellite ? 17.5 : 20.0,
      null,
    );
    await mapboxMap.easeTo(camera, MapAnimationOptions(duration: 650));
  }

  Future<void> _showNearestPropertyCardForCurrentCamera() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null || _mappableProperties.isEmpty) return;

    final CameraState cameraState = await mapboxMap.getCameraState();
    if (!mounted || cameraState.zoom < _mapAutoCardMinZoom) return;

    final List<_MappableProperty> properties = List<_MappableProperty>.from(
      _mappableProperties,
    );
    final List<ScreenCoordinate?> screenCoordinates = await mapboxMap
        .pixelsForCoordinates(
          properties.map((property) => property.point).toList(growable: false),
        );
    if (!mounted) return;

    final Size mapSize = MediaQuery.sizeOf(context);
    final double centerX = mapSize.width / 2;
    final double centerY = mapSize.height / 2;

    _MappableProperty? nearestProperty;
    double nearestDistanceSquared = double.infinity;
    for (int index = 0; index < screenCoordinates.length; index++) {
      final ScreenCoordinate? screenCoordinate = screenCoordinates[index];
      if (screenCoordinate == null) continue;

      final double distanceX = screenCoordinate.x - centerX;
      final double distanceY = screenCoordinate.y - centerY;
      final double distanceSquared =
          distanceX * distanceX + distanceY * distanceY;
      if (distanceSquared < nearestDistanceSquared) {
        nearestDistanceSquared = distanceSquared;
        nearestProperty = properties[index];
      }
    }

    if (nearestProperty == null ||
        nearestDistanceSquared >
            _mapAutoCardPixelRadius * _mapAutoCardPixelRadius) {
      return;
    }
    final _MappableProperty selectedProperty = nearestProperty;
    final double nextCardScale = _cardScaleForZoom(cameraState.zoom);
    final bool selectedPropertyChanged =
        _selectedPropertyId != selectedProperty.property.id;
    final bool cardScaleChanged =
        (_selectedCardScale - nextCardScale).abs() >= 0.01;
    if (!selectedPropertyChanged &&
        _isSelectedCardVisible &&
        !cardScaleChanged) {
      return;
    }

    setState(() {
      _selectedPropertyId = selectedProperty.property.id;
      _isSelectedCardVisible = true;
      _selectedCardScale = nextCardScale;
    });
    if (selectedPropertyChanged) {
      _warmMapPropertyImages([selectedProperty]);
      unawaited(_clearRoutePolyline());
      unawaited(_syncSelectedBoundary());
      unawaited(_syncSelectedLabel()); // NEW
      unawaited(_syncAnnotations(resetCamera: false));
      unawaited(_updateSelectedElevation(selectedProperty));
    }
  }

  Future<void> _syncAnnotations({required bool resetCamera}) async {
    final CircleAnnotationManager? annotationManager = _circleAnnotationManager;
    if (annotationManager == null) return;

    final List<_MappableProperty> properties = List<_MappableProperty>.from(
      _mappableProperties,
    );
    final int syncVersion = ++_annotationSyncVersion;

    if (mounted &&
        properties.every((item) => item.property.id != _selectedPropertyId)) {
      setState(() {
        _selectedPropertyId = null;
        _isSelectedCardVisible = true;
        _selectedCardScale = 1.0;
        _clearSelectedElevation();
      });
      unawaited(_syncSelectedBoundary());
      unawaited(_syncSelectedLabel()); // NEW
      unawaited(_clearRoutePolyline());
    }

    await annotationManager.deleteAll();
    if (!mounted || syncVersion != _annotationSyncVersion) return;

    if (properties.isEmpty) {
      if (resetCamera || !_hasFittedCamera) {
        await _fitCameraToNegrosPlaces();
        if (!mounted || syncVersion != _annotationSyncVersion) return;
        _hasFittedCamera = true;
      }
      return;
    }

    final int initialCount = properties.length < _initialMapAnnotationBatchSize
        ? properties.length
        : _initialMapAnnotationBatchSize;

    await annotationManager.createMulti(
      properties
          .take(initialCount)
          .map(_buildAnnotation)
          .toList(growable: false),
    );
    if (!mounted || syncVersion != _annotationSyncVersion) return;

    _warmMapPropertyImages(properties.take(initialCount));

    if (resetCamera || !_hasFittedCamera) {
      await _fitCameraToNegrosPlaces();
      if (!mounted || syncVersion != _annotationSyncVersion) return;
      _hasFittedCamera = true;
    }

    for (
      int start = initialCount;
      start < properties.length;
      start += _mapAnnotationBatchSize
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
      if (!mounted || syncVersion != _annotationSyncVersion) return;

      final int end = start + _mapAnnotationBatchSize > properties.length
          ? properties.length
          : start + _mapAnnotationBatchSize;

      await annotationManager.createMulti(
        properties
            .sublist(start, end)
            .map(_buildAnnotation)
            .toList(growable: false),
      );
      if (!mounted || syncVersion != _annotationSyncVersion) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MapboxConfig.accessToken.isEmpty) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.map_outlined,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mapbox access token is missing.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add MAPBOX_ACCESS_TOKEN to .env or run the app with --dart-define ACCESS_TOKEN=YOUR_PUBLIC_MAPBOX_ACCESS_TOKEN to load the map.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final _MappableProperty? selectedProperty = _selectedMappedProperty;
    final String? selectedBoundaryCoordinates =
        selectedProperty?.property.boundaryCoordinates;
    final bool selectedPropertyHasBoundary =
        _boundaryPositionsFromText(selectedBoundaryCoordinates) != null;

    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: MapWidget(
              key: ValueKey(_currentStyleUri),
              styleUri: _currentStyleUri,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              cameraOptions: CameraOptions(
                center: _negrosIslandCenter,
                zoom: _negrosIslandInitialZoom,
              ),
              viewport: _mapViewport,
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
              onMapIdleListener: (_) {
                if (!_shouldShowCardAfterUserZoom) return;
                _shouldShowCardAfterUserZoom = false;
                unawaited(_showNearestPropertyCardForCurrentCamera());
              },
              onZoomListener: (_) {
                _shouldShowCardAfterUserZoom = true;
              },
              onTapListener: (_) {
                if (_selectedPropertyId == null) return;
                bool shouldClearRoute = false;
                setState(() {
                  if (_isSelectedCardVisible) {
                    _isSelectedCardVisible = false;
                  } else {
                    _selectedPropertyId = null;
                    _isSelectedCardVisible = true;
                    _selectedCardScale = 1.0;
                    _clearSelectedElevation();
                    shouldClearRoute = true;
                  }
                });
                if (shouldClearRoute) {
                  unawaited(_clearRoutePolyline());
                }
                unawaited(_syncSelectedBoundary());
                unawaited(_syncSelectedLabel()); // NEW
                unawaited(_syncAnnotations(resetCamera: false));
              },
            ),
          ),
          if (_negrosPlaces.isNotEmpty)
            Positioned(
              top: 16,
              left: 16,
              right: 96,
              child: _MapPlacesSearchBar(onTap: _openNegrosPlacesSheet),
            ),
          Positioned(
            top: 16,
            right: 16,
            child: _MapZoomControl(
              onZoomIn: _zoomIn,
              onZoomOut: _zoomOut,
              onToggleMapStyle: _toggleMapStyleMode,
              onResetNorth: _resetNorth,
              // NEW: fit-all and my-location buttons
              onFitAll: _fitCameraToAllProperties,
              onMyLocation: _toggleMyLocation,
              isLocationEnabled: _isLocationEnabled,
              selectedMapStyleMode: _selectedMapStyleMode,
            ),
          ),
          // NEW: "X lots available" badge at bottom-left
          if (_mappableProperties.isNotEmpty)
            Positioned(
              bottom: 48,
              left: 16,
              child: _MapPropertyCountBadge(
                count: _mappableProperties.length,
                onTap: _togglePropertyPickerFromBadge,
              ),
            ),
          if (_mappableProperties.isNotEmpty)
            Positioned(
              bottom: 48,
              right: 16,
              child: _MapDirectionFloatingButton(
                onTap: _showRouteToSelectedProperty,
              ),
            ),
          if (_isPropertyPickerVisible && _mappableProperties.isNotEmpty)
            Positioned(
              bottom: 96,
              left: 16,
              child: _MapPropertyPicker(
                properties: _mappableProperties,
                selectedPropertyId: _selectedPropertyId,
                onSelected: _selectAvailablePropertyFromBadge,
              ),
            ),
          if (selectedProperty != null && _isSelectedCardVisible)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedScale(
                  scale: _selectedCardScale,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: math.max(0.72, _selectedCardScale),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: _SelectedMapPropertyCard(
                      property: selectedProperty.property,
                      isSaved: widget.savedProperties.contains(
                        selectedProperty.property,
                      ),
                      hasBoundary: selectedPropertyHasBoundary,
                      isLoadingElevation: _isLoadingElevation,
                      elevationMeters: _selectedElevationMeters,
                      onToggleSave: () =>
                          widget.onToggleSave(selectedProperty.property),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NegrosPlacesSheet extends StatefulWidget {
  final Map<String, List<NegrosPlace>> groupedPlaces;

  const _NegrosPlacesSheet({required this.groupedPlaces});

  @override
  State<_NegrosPlacesSheet> createState() => _NegrosPlacesSheetState();
}

class _NegrosPlacesSheetState extends State<_NegrosPlacesSheet> {
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double keyboardBottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final String normalizedQuery = _searchQuery.trim().toLowerCase();

    final List<MapEntry<String, List<NegrosPlace>>> visibleEntries = widget
        .groupedPlaces
        .entries
        .map((entry) {
          if (normalizedQuery.isEmpty) return entry;

          final List<NegrosPlace> matchingPlaces = entry.value
              .where((place) {
                final String searchableText =
                    '${place.placeName} ${place.province} ${place.location}'
                        .toLowerCase();

                return searchableText.contains(normalizedQuery);
              })
              .toList(growable: false);

          return MapEntry<String, List<NegrosPlace>>(entry.key, matchingPlaces);
        })
        .where((entry) => entry.value.isNotEmpty)
        .toList(growable: false);

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardBottomInset),
        child: FractionallySizedBox(
          heightFactor: 0.72,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            children: [
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textInputAction: TextInputAction.search,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search Negros places',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (visibleEntries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No places found',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                ...visibleEntries.map((entry) {
                  final List<NegrosPlace> places = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      initiallyExpanded: normalizedQuery.isNotEmpty,
                      leading: const Icon(Icons.location_city_outlined),
                      title: Text(entry.key),
                      subtitle: Text('${places.length} places'),
                      children: places
                          .map((place) {
                            return ListTile(
                              dense: true,
                              title: Text(place.placeName),
                              subtitle: Text(place.location),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).pop(place),
                            );
                          })
                          .toList(growable: false),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// UPDATED: added map style, onFitAll, onMyLocation, isLocationEnabled
class _MapZoomControl extends StatelessWidget {
  final Future<void> Function() onZoomIn;
  final Future<void> Function() onZoomOut;
  final Future<void> Function() onToggleMapStyle;
  final Future<void> Function() onResetNorth;
  final Future<void> Function() onFitAll;
  final Future<void> Function() onMyLocation;
  final bool isLocationEnabled;
  final _MapStyleMode selectedMapStyleMode;

  const _MapZoomControl({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onToggleMapStyle,
    required this.onResetNorth,
    required this.onFitAll,
    required this.onMyLocation,
    required this.isLocationEnabled,
    required this.selectedMapStyleMode,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 38,
            offset: Offset(0, 22),
            color: Color(0x42000000),
          ),
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 6),
            color: Color(0x24000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.32),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MapIconButton(icon: Icons.add, onTap: onZoomIn),
                _MapDivider(color: theme.dividerColor),
                _MapIconButton(icon: Icons.remove, onTap: onZoomOut),
                _MapDivider(color: theme.dividerColor),
                _MapIconButton(
                  icon: selectedMapStyleMode == _MapStyleMode.satellite
                      ? Icons.public_rounded
                      : Icons.layers_outlined,
                  iconSize: 20,
                  onTap: onToggleMapStyle,
                ),
                _MapDivider(color: theme.dividerColor),
                _MapIconButton(
                  icon: Icons.navigation,
                  iconSize: 18,
                  onTap: onResetNorth,
                ),
                _MapDivider(color: theme.dividerColor),
                // NEW: fit all listed properties into view
                _MapIconButton(
                  icon: Icons.fit_screen_rounded,
                  iconSize: 20,
                  onTap: onFitAll,
                ),
                _MapDivider(color: theme.dividerColor),
                // NEW: toggle GPS location puck; icon changes when active
                _MapIconButton(
                  icon: isLocationEnabled
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  iconSize: 20,
                  onTap: onMyLocation,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapIconButton extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final Future<void> Function() onTap;

  const _MapIconButton({
    required this.icon,
    required this.onTap,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    const List<Shadow> iconShadows = [
      Shadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x99000000)),
      Shadow(blurRadius: 3, offset: Offset(0, 1), color: Color(0x66000000)),
    ];

    return InkWell(
      onTap: () {
        unawaited(onTap());
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: iconSize, shadows: iconShadows),
      ),
    );
  }
}

class _MapDivider extends StatelessWidget {
  final Color color;

  const _MapDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 1,
      color: color.withValues(alpha: 0.55),
    );
  }
}

class _SelectedMapPropertyCard extends StatelessWidget {
  final Property property;
  final bool isSaved;
  final bool hasBoundary;
  final bool isLoadingElevation;
  final double? elevationMeters;
  final VoidCallback onToggleSave;

  const _SelectedMapPropertyCard({
    required this.property,
    required this.isSaved,
    required this.hasBoundary,
    required this.isLoadingElevation,
    required this.elevationMeters,
    required this.onToggleSave,
  });

  void _openDetails(BuildContext context) {
    unawaited(precachePropertyImage(context, property, height: 300));
    Navigator.push(
      context,
      instantRoute(
        PropertyDetailsScreen(
          property: property,
          isSaved: isSaved,
          onToggleSave: onToggleSave,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String description = property.description.trim().isEmpty
        ? 'No description available for this lot yet.'
        : property.description;
    final String elevationLabel = isLoadingElevation
        ? 'Elevation loading'
        : elevationMeters == null
        ? 'Elevation unavailable'
        : 'Elevation ~${elevationMeters!.round()} m';
    final double cardWidth = math.min(
      390.0,
      math.max(280.0, MediaQuery.sizeOf(context).width - 32),
    );
    final double cardHeight = math.min(
      420.0,
      math.max(370.0, MediaQuery.sizeOf(context).height * 0.60),
    );
    final double thumbnailSize = math.min(
      136.0,
      math.max(120.0, cardWidth * 0.36),
    );

    return SizedBox(
      width: cardWidth,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: cardHeight,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: thumbnailSize,
                      height: thumbnailSize,
                      child: buildPropertyImage(
                        context: context,
                        property: property,
                        height: thumbnailSize,
                        borderRadius: BorderRadius.circular(14),
                        fallbackChild: const Center(
                          child: Icon(
                            Icons.landscape_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            property.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            property.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            property.price,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _MapPropertyInfoChip(
                                icon: Icons.square_foot_rounded,
                                label: property.size,
                              ),
                              _MapPropertyInfoChip(
                                icon: Icons.verified_outlined,
                                label: property.titleStatus,
                              ),
                              _MapPropertyInfoChip(
                                icon: Icons.landscape_rounded,
                                label: elevationLabel,
                              ),
                              _MapPropertyInfoChip(
                                icon: Icons.polyline_outlined,
                                label: hasBoundary
                                    ? 'Boundary shown'
                                    : 'No boundary',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _openDetails(context),
                  icon: const Icon(Icons.open_in_new_rounded, size: 17),
                  label: const Text('View Details'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPropertyInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MapPropertyInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.78,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPlacesSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _MapPlacesSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 28,
            spreadRadius: -6,
            offset: Offset(0, 14),
            color: Color(0x4D000000),
          ),
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 3),
            color: Color(0x26000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: theme.colorScheme.surface.withValues(alpha: 0.46),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(
                height: 48,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: theme.colorScheme.onSurface,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Search Negros places',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// NEW: badge widget showing total listed lots available on the map
class _MapPropertyCountBadge extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const _MapPropertyCountBadge({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const List<Shadow> floatingShadows = [
      Shadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x99000000)),
      Shadow(blurRadius: 3, offset: Offset(0, 1), color: Color(0x66000000)),
    ];

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.landscape_rounded,
              size: 16,
              color: theme.colorScheme.primary,
              shadows: floatingShadows,
            ),
            const SizedBox(width: 6),
            Text(
              '$count lot${count == 1 ? '' : 's'} available',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                shadows: floatingShadows,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapDirectionFloatingButton extends StatelessWidget {
  final Future<void> Function() onTap;

  const _MapDirectionFloatingButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    const List<Shadow> iconShadows = [
      Shadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x99000000)),
      Shadow(blurRadius: 3, offset: Offset(0, 1), color: Color(0x66000000)),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 30,
            spreadRadius: -5,
            offset: Offset(0, 16),
            color: Color(0x44000000),
          ),
          BoxShadow(
            blurRadius: 8,
            offset: Offset(0, 4),
            color: Color(0x26000000),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => unawaited(onTap()),
            borderRadius: BorderRadius.circular(18),
            child: const SizedBox(
              width: 56,
              height: 56,
              child: Icon(
                Icons.directions_rounded,
                size: 32,
                color: Colors.white,
                shadows: iconShadows,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapPropertyPicker extends StatelessWidget {
  final List<_MappableProperty> properties;
  final String? selectedPropertyId;
  final ValueChanged<_MappableProperty> onSelected;

  const _MapPropertyPicker({
    required this.properties,
    required this.selectedPropertyId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final _MappableProperty item in properties) ...[
          _MapPropertyPickerButton(
            item: item,
            isSelected: item.property.id == selectedPropertyId,
            onTap: () => onSelected(item),
          ),
          if (item != properties.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _MapPropertyPickerButton extends StatelessWidget {
  final _MappableProperty item;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapPropertyPickerButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const List<Shadow> childShadows = [
      Shadow(blurRadius: 10, offset: Offset(0, 4), color: Color(0x99000000)),
      Shadow(blurRadius: 3, offset: Offset(0, 1), color: Color(0x66000000)),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 26,
            spreadRadius: -8,
            offset: Offset(0, 14),
            color: Color(0x38000000),
          ),
          BoxShadow(
            blurRadius: 12,
            spreadRadius: -6,
            offset: Offset(0, 4),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 230,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.property.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.white,
                        fontWeight: FontWeight.w800,
                        shadows: childShadows,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.property.price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w700,
                        shadows: childShadows,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
