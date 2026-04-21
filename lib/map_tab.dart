part of 'main.dart';

const int _initialMapAnnotationBatchSize = 8;
const int _mapAnnotationBatchSize = 12;
const int _maxMapPrecachedThumbnails = 4;
const double _mapAutoCardMinZoom = 13.25;
const double _mapAutoCardFullZoom = 18.0;
const double _mapAutoCardMinScale = 0.52;
const double _mapAutoCardPixelRadius = 112.0;
final Point _negrosIslandCenter = Point(
  coordinates: Position(123.02, 10.1),
);
const double _negrosIslandInitialZoom = 7.35;
const String _mapTerrainSourceId = 'property-terrain-dem';
const String _mapboxAccessTokenFallback = String.fromEnvironment(
  'ACCESS_TOKEN',
);
String _mapboxAccessToken = _mapboxAccessTokenFallback;

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

  const MapTab({
    super.key,
    required this.savedProperties,
    required this.onToggleSave,
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
  Cancelable? _annotationTapCancelable;

  int _annotationSyncVersion = 0;
  int _elevationRequestVersion = 0;
  bool _hasFittedCamera = false;
  bool _isLoadingElevation = false;
  bool _isSelectedCardVisible = true;
  bool _shouldShowCardAfterUserZoom = false;
  double _selectedCardScale = 1.0;
  double? _selectedElevationMeters;
  String? _selectedPropertyId;
  _MapStyleMode _selectedMapStyleMode = _MapStyleMode.monochrome;
  String _currentStyleUri = MapboxStyles.STANDARD;
  _MapLightPreset _selectedLightPreset = _MapLightPreset.day;

  // NEW: price label annotation manager and location puck toggle
  PointAnnotationManager? _labelAnnotationManager;
  bool _isLocationEnabled = false;

  @override
  void initState() {
    super.initState();
    appPropertiesNotifier.addListener(_handlePropertiesChanged);
    appNegrosPlacesNotifier.addListener(_handleNegrosPlacesChanged);
    _warmMapPropertyImages(
      _mappableProperties.take(_initialPropertyImagePrefetchCount),
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

    if (!mounted) return;

    setState(() {
      _mappableProperties = nextProperties;
      final bool hasSelectedProperty = nextProperties.any(
        (item) => item.property.id == _selectedPropertyId,
      );
      if (!hasSelectedProperty) {
        _selectedPropertyId = null;
        _isSelectedCardVisible = true;
        _selectedCardScale = 1.0;
        _selectedElevationMeters = null;
        _isLoadingElevation = false;
        _elevationRequestVersion++;
      }
    });

    _warmMapPropertyImages(
      nextProperties.take(_initialPropertyImagePrefetchCount),
    );
    unawaited(_syncSelectedBoundary());
    unawaited(_syncSelectedLabel()); // NEW
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
          _warmPropertyImage(context, item.property, useThumbnail: true);
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

  // NEW: toggles Mapbox built-in GPS location puck on/off
  Future<void> _toggleMyLocation() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;

    final bool next = !_isLocationEnabled;
    await mapboxMap.location.updateSettings(
      LocationComponentSettings(
        enabled: next,
        pulsingEnabled: next,
        pulsingColor: Theme.of(context).colorScheme.primary.toARGB32(),
      ),
    );
    if (!mounted) return;
    setState(() => _isLocationEnabled = next);
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
    final Map<String, List<NegrosPlace>> groupedPlaces =
        _groupNegrosPlacesByProvince();

    final NegrosPlace? selectedPlace = await showModalBottomSheet<NegrosPlace>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final ThemeData theme = Theme.of(context);

        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.72,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              children: [
                Text(
                  'Negros Places',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose a province or district group, then select a place.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                ...groupedPlaces.entries.map((entry) {
                  final List<NegrosPlace> places = entry.value;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
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
        );
      },
    );

    if (selectedPlace == null) return;
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
    setState(() {
      _selectedPropertyId = propertyId;
      _isSelectedCardVisible = !hasBoundary;
      _selectedCardScale = 1.0;
    });

    _warmMapPropertyImages([selected]);
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
    if (_mapboxAccessToken.isEmpty) {
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
                setState(() {
                  if (_isSelectedCardVisible) {
                    _isSelectedCardVisible = false;
                  } else {
                    _selectedPropertyId = null;
                    _isSelectedCardVisible = true;
                    _selectedCardScale = 1.0;
                    _clearSelectedElevation();
                  }
                });
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
              child: FilledButton.icon(
                onPressed: _openNegrosPlacesSheet,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Negros places'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
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
              bottom: 16,
              left: 16,
              child: _MapPropertyCountBadge(count: _mappableProperties.length),
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
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x1A000000),
          ),
        ],
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
    return InkWell(
      onTap: () {
        unawaited(onTap());
      },
      child: SizedBox(width: 40, height: 40, child: Icon(icon, size: iconSize)),
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
    unawaited(_precachePropertyImage(context, property, height: 300));
    Navigator.push(
      context,
      _instantRoute(
        PropertyDetailsPage(
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
                      child: _buildPropertyImage(
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

// NEW: badge widget showing total listed lots available on the map
class _MapPropertyCountBadge extends StatelessWidget {
  final int count;

  const _MapPropertyCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            offset: Offset(0, 4),
            color: Color(0x1A000000),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.landscape_rounded,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              '$count lot${count == 1 ? '' : 's'} available',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
