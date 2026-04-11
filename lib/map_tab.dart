part of 'main.dart';

const int _initialMapAnnotationBatchSize = 12;
const int _mapAnnotationBatchSize = 24;
const String _mapboxAccessTokenFallback = String.fromEnvironment(
  'ACCESS_TOKEN',
);
String _mapboxAccessToken = _mapboxAccessTokenFallback;

enum _MapLightPreset { dawn, day, dusk, night }

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
  final List<String> parts = property.location.split(',');
  if (parts.length < 2) return null;

  final double? latitude = double.tryParse(parts[0].trim());
  final double? longitude = double.tryParse(parts[1].trim());
  if (latitude == null || longitude == null) return null;
  if (latitude < -90 || latitude > 90) return null;
  if (longitude < -180 || longitude > 180) return null;

  return _MappableProperty(
    property: property,
    latitude: latitude,
    longitude: longitude,
  );
}

List<_MappableProperty> _extractMappableProperties(Iterable<Property> properties) {
  return properties
      .map(_mappablePropertyFromProperty)
      .whereType<_MappableProperty>()
      .toList(growable: false);
}

class MapTab extends StatefulWidget {
  const MapTab({super.key});

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
  Cancelable? _annotationTapCancelable;

  int _annotationSyncVersion = 0;
  bool _hasCompletedInitialSync = false;
  bool _hasFittedCamera = false;
  String? _selectedPropertyId;
  String _currentStyleUri = MapboxStyles.STANDARD;
  _MapLightPreset _selectedLightPreset = _MapLightPreset.night;

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

    final String nextStyleUri = _styleUriForBrightness(
      Theme.of(context).brightness,
    );
    if (_currentStyleUri == nextStyleUri) return;

    _annotationTapCancelable?.cancel();
    _annotationTapCancelable = null;
    _mapboxMap = null;
    _circleAnnotationManager = null;
    _hasCompletedInitialSync = false;
    _hasFittedCamera = false;
    _currentStyleUri = nextStyleUri;
  }

  @override
  void dispose() {
    appPropertiesNotifier.removeListener(_handlePropertiesChanged);
    appNegrosPlacesNotifier.removeListener(_handleNegrosPlacesChanged);
    _annotationTapCancelable?.cancel();

    final MapboxMap? mapboxMap = _mapboxMap;
    final CircleAnnotationManager? annotationManager = _circleAnnotationManager;
    if (mapboxMap != null && annotationManager != null) {
      unawaited(mapboxMap.annotations.removeAnnotationManager(annotationManager));
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
      }
    });

    _warmMapPropertyImages(
      nextProperties.take(_initialPropertyImagePrefetchCount),
    );
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

      for (final _MappableProperty item in properties) {
        if (_warmedMapPropertyImageIds.add(item.property.id)) {
          _warmPropertyImage(context, item.property, useThumbnail: true);
        }
      }
    });
  }

  String _styleUriForBrightness(Brightness brightness) {
    return MapboxStyles.STANDARD;
  }

  Future<void> _applyStandardStyleConfiguration(MapboxMap mapboxMap) async {
    await mapboxMap.style.setStyleImportConfigProperty(
      'basemap',
      'theme',
      'monochrome',
    );
    await mapboxMap.style.setStyleImportConfigProperty(
      'basemap',
      'lightPreset',
      _selectedLightPreset.name,
    );
    await mapboxMap.style.setStyleImportConfigProperty(
      'basemap',
      'show3dObjects',
      false,
    );
  }

  Future<void> _setLightPreset(_MapLightPreset preset) async {
    if (_selectedLightPreset == preset) return;

    setState(() {
      _selectedLightPreset = preset;
    });

    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;
    await _applyStandardStyleConfiguration(mapboxMap);
  }

  List<Point> _negrosPlacePoints() {
    return _negrosPlaces
        .where((place) => place.latitude != null && place.longitude != null)
        .map(
          (place) => Point(
            coordinates: Position(place.longitude!, place.latitude!),
          ),
        )
        .toList(growable: false);
  }

  Future<void> _focusOnNegrosPlace(NegrosPlace place) async {
    final double? latitude = place.latitude;
    final double? longitude = place.longitude;
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null || latitude == null || longitude == null) return;

    if (mounted) {
      setState(() {
        _selectedPropertyId = null;
      });
    }

    await mapboxMap.easeTo(
      CameraOptions(center: Point(coordinates: Position(longitude, latitude)), zoom: 11.8),
      MapAnimationOptions(duration: 650),
    );
  }

  Future<void> _fitCameraToNegrosPlaces() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    final List<Point> placePoints = _negrosPlacePoints();
    if (mapboxMap == null || placePoints.isEmpty) return;

    final CameraOptions camera = await mapboxMap.cameraForCoordinatesPadding(
      placePoints,
      CameraOptions(),
      MbxEdgeInsets(top: 120, left: 48, bottom: 120, right: 48),
      10.0,
      null,
    );
    await mapboxMap.easeTo(camera, MapAnimationOptions(duration: 700));
  }

  Future<void> _openNegrosPlacesSheet() async {
    final NegrosPlace? selectedPlace = await showModalBottomSheet<NegrosPlace>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _negrosPlaces.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final NegrosPlace place = _negrosPlaces[index];
              return ListTile(
                title: Text(place.placeName),
                subtitle: Text(place.province),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).pop(place),
              );
            },
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
    await mapboxMap.scaleBy(
      2.0,
      null,
      MapAnimationOptions(duration: 220),
    );
  }

  Future<void> _zoomOut() async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null) return;
    await mapboxMap.scaleBy(
      0.5,
      null,
      MapAnimationOptions(duration: 220),
    );
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
    return CircleAnnotationOptions(
      geometry: item.point,
      circleColor: item.property.imageColor.toARGB32(),
      circleRadius: 8,
      circleStrokeColor: Colors.white.toARGB32(),
      circleStrokeWidth: 3,
      circleOpacity: 0.95,
      customData: <String, Object>{'propertyId': item.property.id},
    );
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
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

    _annotationTapCancelable?.cancel();
    final CircleAnnotationManager? existingManager = _circleAnnotationManager;
    if (existingManager != null) {
      unawaited(mapboxMap.annotations.removeAnnotationManager(existingManager));
    }

    final CircleAnnotationManager annotationManager =
        await mapboxMap.annotations.createCircleAnnotationManager(
          id: 'property-markers',
        );
    _circleAnnotationManager = annotationManager;
    _annotationTapCancelable = annotationManager.tapEvents(
      onTap: _handleAnnotationTap,
    );

    await _syncAnnotations(resetCamera: true);
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

    setState(() {
      _selectedPropertyId = propertyId;
    });

    _warmMapPropertyImages([selected]);
    unawaited(
      _mapboxMap?.easeTo(
            CameraOptions(center: selected.point, zoom: 13.5),
            MapAnimationOptions(duration: 450),
          ) ??
          Future<void>.value(),
    );
  }

  Future<void> _fitCameraToProperties(List<_MappableProperty> properties) async {
    final MapboxMap? mapboxMap = _mapboxMap;
    if (mapboxMap == null || properties.isEmpty) return;

    if (properties.length == 1) {
      await mapboxMap.easeTo(
        CameraOptions(center: properties.first.point, zoom: 13.5),
        MapAnimationOptions(duration: 700),
      );
      return;
    }

    final CameraOptions camera = await mapboxMap.cameraForCoordinatesPadding(
      properties.map((item) => item.point).toList(growable: false),
      CameraOptions(),
      MbxEdgeInsets(top: 96, left: 48, bottom: 220, right: 48),
      14.0,
      null,
    );
    await mapboxMap.easeTo(camera, MapAnimationOptions(duration: 700));
  }

  Future<void> _syncAnnotations({required bool resetCamera}) async {
    final CircleAnnotationManager? annotationManager = _circleAnnotationManager;
    if (annotationManager == null) return;

    final List<_MappableProperty> properties = List<_MappableProperty>.from(
      _mappableProperties,
    );
    final int syncVersion = ++_annotationSyncVersion;

    if (mounted && properties.every((item) => item.property.id != _selectedPropertyId)) {
      setState(() {
        _selectedPropertyId = null;
      });
    }

    await annotationManager.deleteAll();
    if (!mounted || syncVersion != _annotationSyncVersion) return;

    if (properties.isEmpty) {
      if (resetCamera || !_hasFittedCamera) {
        await _fitCameraToNegrosPlaces();
        if (!mounted || syncVersion != _annotationSyncVersion) return;
        _hasFittedCamera = true;
      }
      setState(() {
        _hasCompletedInitialSync = true;
      });
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
      await _fitCameraToProperties(properties);
      if (!mounted || syncVersion != _annotationSyncVersion) return;
      _hasFittedCamera = true;
    }

    for (
      int start = initialCount;
      start < properties.length;
      start += _mapAnnotationBatchSize
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 24));
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
      _warmMapPropertyImages(properties.sublist(start, end));
    }

    if (!mounted || syncVersion != _annotationSyncVersion) return;
    setState(() {
      _hasCompletedInitialSync = true;
    });
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
                center: Point(
                  coordinates: Position(123.0, 9.85),
                ),
                zoom: 8.4,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedListener: _onStyleLoaded,
              onTapListener: (_) {
                if (_selectedPropertyId == null) return;
                setState(() {
                  _selectedPropertyId = null;
                });
              },
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: _MapLightPresetToggle(
              selectedPreset: _selectedLightPreset,
              onSelected: _setLightPreset,
            ),
          ),
          if (_negrosPlaces.isNotEmpty)
            Positioned(
              top: 76,
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
              onResetNorth: _resetNorth,
            ),
          ),
          if (selectedProperty != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _SelectedMapPropertyCard(
                property: selectedProperty.property,
              ),
            ),
        ],
      ),
    );
  }
}

class _MapLightPresetToggle extends StatelessWidget {
  final _MapLightPreset selectedPreset;
  final ValueChanged<_MapLightPreset> onSelected;

  const _MapLightPresetToggle({
    required this.selectedPreset,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            blurRadius: 14,
            offset: Offset(0, 6),
            color: Color(0x1A000000),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: _MapLightPreset.values.map((preset) {
            final bool isSelected = preset == selectedPreset;
            final String label = switch (preset) {
              _MapLightPreset.dawn => 'Dawn',
              _MapLightPreset.day => 'Day',
              _MapLightPreset.dusk => 'Dusk',
              _MapLightPreset.night => 'Night',
            };

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelected(preset),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.outline.withValues(alpha: 0.75)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }
}

class _MapZoomControl extends StatelessWidget {
  final Future<void> Function() onZoomIn;
  final Future<void> Function() onZoomOut;
  final Future<void> Function() onResetNorth;

  const _MapZoomControl({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetNorth,
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
          _MapIconButton(
            icon: Icons.add,
            onTap: onZoomIn,
          ),
          _MapDivider(color: theme.dividerColor),
          _MapIconButton(
            icon: Icons.remove,
            onTap: onZoomOut,
          ),
          _MapDivider(color: theme.dividerColor),
          _MapIconButton(
            icon: Icons.navigation,
            iconSize: 18,
            onTap: onResetNorth,
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
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, size: iconSize),
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

  const _SelectedMapPropertyCard({required this.property});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 82,
                height: 82,
                child: _buildPropertyImage(
                  context: context,
                  property: property,
                  height: 82,
                  useThumbnail: true,
                  fallbackChild: const Center(
                    child: Icon(
                      Icons.landscape_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    property.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    property.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    property.price,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
