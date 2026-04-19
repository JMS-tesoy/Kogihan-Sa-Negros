import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide ImageSource, Size;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'agent_dashboard_page.dart';
import 'messaging_service.dart';
import 'negros_places.dart';
import 'shared_properties.dart';
import 'subscription.dart';
import 'subscription_screen.dart';

part 'map_tab.dart';

final ValueNotifier<ThemeMode> appThemeNotifier = ValueNotifier(
  ThemeMode.light,
);
final ValueNotifier<double> appFontScaleNotifier = ValueNotifier(1.0);
final ValueNotifier<String?> appPinCodeNotifier = ValueNotifier(null);
const String _savedPropertyIdsPrefsKey = 'saved_property_ids';
const int _initialPropertyImagePrefetchCount = 4;
const String _authRedirectUrl =
    'com.example.flutterapplication1://login-callback/';

String _messageInitial(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return '?';
  return trimmed[0].toUpperCase();
}

String _formatInboxTimestamp(DateTime? value) {
  if (value == null) return '';

  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final DateTime localValue = value.toLocal();
  final int hour = localValue.hour % 12 == 0 ? 12 : localValue.hour % 12;
  final String minute = localValue.minute.toString().padLeft(2, '0');
  final String suffix = localValue.hour >= 12 ? 'PM' : 'AM';

  return '${months[localValue.month - 1]} ${localValue.day}, $hour:$minute $suffix';
}

String _formatSubscriptionDate(DateTime? value) {
  if (value == null) return 'No renewal date yet';

  const List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  final DateTime localValue = value.toLocal();
  return '${months[localValue.month - 1]} ${localValue.day}, ${localValue.year}';
}

ImageProvider<Object>? _propertyImageProvider(
  Property property, {
  int? targetWidth,
  bool useThumbnail = false,
}) {
  final String? imageUrl = resolvePropertyImageUrl(
    property,
    preferThumbnail: useThumbnail,
    targetWidth: useThumbnail ? targetWidth : null,
  );
  if (imageUrl == null || imageUrl.isEmpty) return null;
  if (imageUrl.startsWith('http')) {
    return CachedNetworkImageProvider(imageUrl);
  }
  return AssetImage(imageUrl);
}

ImageProvider<Object>? _propertyDisplayImageProvider(
  BuildContext context,
  Property property, {
  required double height,
  bool useThumbnail = false,
}) {
  final double devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
  final int targetWidth = (MediaQuery.sizeOf(context).width * 1.5)
      .round()
      .clamp(480, 900);
  final ImageProvider<Object>? imageProvider = _propertyImageProvider(
    property,
    targetWidth: targetWidth,
    useThumbnail: useThumbnail,
  );
  if (imageProvider == null) return null;

  return ResizeImage.resizeIfNeeded(
    (MediaQuery.sizeOf(context).width * devicePixelRatio).round(),
    (height * devicePixelRatio).round(),
    imageProvider,
  );
}

String _buyerInboxConversationTitle(ConversationSummary conversation) {
  final String propertyTitle = (conversation.propertyTitle ?? '').trim();
  if (propertyTitle.isNotEmpty) return propertyTitle;
  return conversation.title;
}

ImageProvider<Object>? _buyerInboxConversationImageProvider(
  BuildContext context,
  ConversationSummary conversation,
) {
  final String? rawImageUrl = (() {
    final String thumbnailUrl = (conversation.propertyThumbnailUrl ?? '')
        .trim();
    if (thumbnailUrl.isNotEmpty) return thumbnailUrl;

    final String imageUrl = (conversation.propertyImageUrl ?? '').trim();
    if (imageUrl.isNotEmpty) return imageUrl;

    return null;
  })();

  if (rawImageUrl == null || rawImageUrl.isEmpty) return null;
  if (rawImageUrl.startsWith('http')) {
    return CachedNetworkImageProvider(rawImageUrl);
  }
  return AssetImage(rawImageUrl);
}

void _warmPropertyImage(
  BuildContext context,
  Property property, {
  double height = 210,
  bool useThumbnail = false,
}) {
  final ImageProvider<Object>? imageProvider = _propertyDisplayImageProvider(
    context,
    property,
    height: height,
    useThumbnail: useThumbnail,
  );
  if (imageProvider == null) return;
  unawaited(precacheImage(imageProvider, context));
}

Future<void> _precachePropertyImage(
  BuildContext context,
  Property property, {
  double height = 210,
  bool useThumbnail = false,
}) async {
  final ImageProvider<Object>? imageProvider = _propertyDisplayImageProvider(
    context,
    property,
    height: height,
    useThumbnail: useThumbnail,
  );
  if (imageProvider == null) return;
  await precacheImage(imageProvider, context);
}

Route<T> _instantRoute<T>(Widget child) {
  return PageRouteBuilder<T>(
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (context, animation, secondaryAnimation) => child,
  );
}

Widget _buildPropertyImage({
  required BuildContext context,
  required Property property,
  required double height,
  required Widget fallbackChild,
  BorderRadius? borderRadius,
  bool useThumbnail = false,
}) {
  final Widget fallback = Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [
          property.imageColor,
          property.imageColor.withValues(alpha: 0.78),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: fallbackChild,
  );

  final ImageProvider<Object>? imageProvider = _propertyDisplayImageProvider(
    context,
    property,
    height: height,
    useThumbnail: useThumbnail,
  );
  if (imageProvider == null) {
    return borderRadius == null
        ? fallback
        : ClipRRect(borderRadius: borderRadius, child: fallback);
  }

  final Widget image = Image(
    image: imageProvider,
    height: height,
    width: double.infinity,
    fit: BoxFit.cover,
    filterQuality: FilterQuality.low,
    gaplessPlayback: true,
    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
      if (wasSynchronouslyLoaded || frame != null) {
        return child;
      }
      return fallback;
    },
    loadingBuilder:
        resolvePropertyImageUrl(
              property,
              preferThumbnail: useThumbnail,
            )?.startsWith('http') ==
            true
        ? (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return fallback;
          }
        : null,
    errorBuilder: (context, error, stackTrace) => fallback,
  );

  return borderRadius == null
      ? image
      : ClipRRect(borderRadius: borderRadius, child: image);
}

ThemeData _buildLightTheme() {
  const Color seedColor = Color(0xFF2563EB);
  final ColorScheme scheme =
      ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF2563EB),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFDBEAFE),
        onPrimaryContainer: const Color(0xFF123B7A),
        secondary: const Color(0xFF64748B),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFE8EEF6),
        onSecondaryContainer: const Color(0xFF243449),
        surface: const Color(0xFFFFFFFF),
        onSurface: const Color(0xFF0F172A),
        surfaceContainerHighest: const Color(0xFFEEF2F6),
        onSurfaceVariant: const Color(0xFF475569),
        outline: const Color(0xFFD7DFE8),
        outlineVariant: const Color(0xFFE6ECF2),
        shadow: const Color(0xFF0F172A),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    cardColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    canvasColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        surfaceTintColor: Colors.transparent,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.primary),
    ),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: '.env');
    final String envToken = dotenv.env['MAPBOX_ACCESS_TOKEN']?.trim() ?? '';
    if (envToken.isNotEmpty) {
      _mapboxAccessToken = envToken;
    }
  } catch (_) {}

  if (_mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(_mapboxAccessToken);
  }

  try {
    await Supabase.initialize(
      // TODO: Paste your actual Supabase URL and Anon Key here
      url: 'https://vludvvjkrrqzjahxjdjl.supabase.co',
      anonKey: 'sb_publishable_xrlYmyU6k2ItwhoSycq_iQ_4RxiPGdJ',
    );
    unawaited(loadProperties());
    unawaited(loadNegrosPlaces());
    developer.log('✅ Supabase connected successfully!', name: 'Supabase');
  } catch (e, stackTrace) {
    developer.log(
      '❌ Supabase connection failed',
      name: 'Supabase',
      error: e,
      stackTrace: stackTrace,
    );
  }

  await SubscriptionService.initialize();

  runApp(const RealEstateApp());
}

class RealEstateApp extends StatelessWidget {
  const RealEstateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: appThemeNotifier,
      builder: (context, currentMode, child) {
        return ValueListenableBuilder<double>(
          valueListenable: appFontScaleNotifier,
          builder: (context, fontScale, child) {
            return MaterialApp(
              title: 'Land Finder',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(fontScale)),
                  child: child!,
                );
              },
              theme: _buildLightTheme(),
              darkTheme: ThemeData(
                useMaterial3: true,
                colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF2E7D32),
                  brightness: Brightness.dark,
                ),
                scaffoldBackgroundColor: const Color(0xFF121212),
              ),
              home: const LoginPage(),
            );
          },
        );
      },
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _selectedLocation;
  String? _selectedLotSize;
  String? _selectedBudget;
  final Set<String> _savedPropertyIds = <String>{};
  final Set<Property> _savedProperties = {};
  final Set<String> _warmedPropertyImageIds = <String>{};
  List<NegrosPlace> _negrosPlaces = List<NegrosPlace>.from(
    appNegrosPlacesNotifier.value,
  );
  List<Property> _availableProperties = List<Property>.from(
    appPropertiesNotifier.value,
  );

  Uint8List? _profileImageBytes;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    appPropertiesNotifier.addListener(_syncAvailableProperties);
    appNegrosPlacesNotifier.addListener(_syncNegrosPlaces);
    appSubscriptionNotifier.addListener(_handleSubscriptionChanged);
    _warmInitialPropertyCardImages(_availableProperties);
    unawaited(_restoreSavedProperties());
    unawaited(_syncSubscriptionFromProfile());
  }

  @override
  void dispose() {
    appPropertiesNotifier.removeListener(_syncAvailableProperties);
    appNegrosPlacesNotifier.removeListener(_syncNegrosPlaces);
    appSubscriptionNotifier.removeListener(_handleSubscriptionChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _syncAvailableProperties() {
    if (!mounted) return;
    setState(() {
      _availableProperties = List<Property>.from(appPropertiesNotifier.value);
      _savedProperties
        ..clear()
        ..addAll(
          _availableProperties.where(
            (property) => _savedPropertyIds.contains(property.id),
          ),
        );
    });
    _warmInitialPropertyCardImages(_availableProperties);
  }

  void _handleSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _syncNegrosPlaces() {
    if (!mounted) return;
    setState(() {
      _negrosPlaces = List<NegrosPlace>.from(appNegrosPlacesNotifier.value);
    });
  }

  List<double>? _parseCoordinates(String value) {
    final List<String> parts = value.split(',');
    if (parts.length < 2) return null;

    final double? latitude = double.tryParse(parts[0].trim());
    final double? longitude = double.tryParse(parts[1].trim());
    if (latitude == null || longitude == null) return null;

    return <double>[latitude, longitude];
  }

  double _distanceInKm({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const double earthRadiusKm = 6371;
    final double latitudeDelta = _degreesToRadians(endLatitude - startLatitude);
    final double longitudeDelta = _degreesToRadians(
      endLongitude - startLongitude,
    );
    final double a =
        math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
        math.cos(_degreesToRadians(startLatitude)) *
            math.cos(_degreesToRadians(endLatitude)) *
            math.sin(longitudeDelta / 2) *
            math.sin(longitudeDelta / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180);

  Future<void> _syncSubscriptionFromProfile() async {
    final UserSubscription currentSubscription = appSubscriptionNotifier.value;
    final bool hasLocalSubscriptionData =
        currentSubscription.tier != SubscriptionTier.free ||
        currentSubscription.expiresAt != null;
    if (hasLocalSubscriptionData) return;

    try {
      final MessagingProfile? profile =
          await MessagingService.fetchCurrentProfile();
      if (profile?.subscription == null) return;
      appSubscriptionNotifier.value = profile!.subscription!;
    } catch (_) {}
  }

  void _warmInitialPropertyCardImages(List<Property> properties) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final Property property in properties.take(
        _initialPropertyImagePrefetchCount,
      )) {
        if (_warmedPropertyImageIds.add(property.id)) {
          _warmPropertyImage(context, property, useThumbnail: true);
        }
      }
    });
  }

  String _normalizeSearchText(String value) {
    return value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _restoreSavedProperties() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final Set<String> savedIds =
        preferences.getStringList(_savedPropertyIdsPrefsKey)?.toSet() ??
        <String>{};

    if (!mounted || savedIds.isEmpty) return;

    setState(() {
      _savedPropertyIds
        ..clear()
        ..addAll(savedIds);
      _savedProperties
        ..clear()
        ..addAll(
          _availableProperties.where(
            (property) => _savedPropertyIds.contains(property.id),
          ),
        );
    });
  }

  Future<void> _persistSavedProperties() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _savedPropertyIdsPrefsKey,
      _savedPropertyIds.toList(),
    );
  }

  Future<void> _openSubscriptionPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SubscriptionPage()),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showSavedPropertiesUpgradePrompt() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium feature',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Free users can save up to $freeSavedPropertiesLimit lots. Upgrade to premium for unlimited saved listings.',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _openSubscriptionPage();
                    },
                    child: const Text('View Plans'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Not Now'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAvatarFromGallery() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final Uint8List imageBytes = await pickedFile.readAsBytes();
      setState(() {
        _profileImageBytes = imageBytes;
      });
    }
  }

  Future<void> _pickAvatarFromCamera() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      final Uint8List imageBytes = await pickedFile.readAsBytes();
      setState(() {
        _profileImageBytes = imageBytes;
      });
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatarFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAvatarFromCamera();
                },
              ),
              if (_profileImageBytes != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Remove Avatar',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _profileImageBytes = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  List<Property> get _filteredProperties {
    final String normalizedQuery = _normalizeSearchText(_searchQuery);
    final String numericQuery = _digitsOnly(_searchQuery);
    final bool hasSearchQuery =
        normalizedQuery.isNotEmpty || numericQuery.isNotEmpty;
    final bool hasLocationFilter = _selectedLocation != null;
    final bool hasLotSizeFilter = _selectedLotSize != null;
    final bool hasBudgetFilter = _selectedBudget != null;

    if (!hasSearchQuery &&
        !hasLocationFilter &&
        !hasLotSizeFilter &&
        !hasBudgetFilter) {
      return List<Property>.from(_availableProperties);
    }

    return _availableProperties
        .where((property) {
          if (hasLocationFilter) {
            final NegrosPlace? selectedPlace = _negrosPlaces.cast<NegrosPlace?>().firstWhere(
              (place) => place?.placeName == _selectedLocation,
              orElse: () => null,
            );

            if (selectedPlace != null) {
              final List<double>? propertyCoordinates = _parseCoordinates(
                property.location,
              );
              final double? placeLatitude = selectedPlace.latitude;
              final double? placeLongitude = selectedPlace.longitude;

              if (propertyCoordinates == null ||
                  placeLatitude == null ||
                  placeLongitude == null) {
                return false;
              }

              final double distanceInKm = _distanceInKm(
                startLatitude: propertyCoordinates[0],
                startLongitude: propertyCoordinates[1],
                endLatitude: placeLatitude,
                endLongitude: placeLongitude,
              );

              if (distanceInKm > 25) return false;
            } else if (property.location != _selectedLocation) {
              return false;
            }
          }

          if (hasLotSizeFilter) {
            final bool matchesLotSize = switch (_selectedLotSize) {
              'Below 500 sqm' => property.sizeValue < 500,
              '500 - 1000 sqm' =>
                property.sizeValue >= 500 && property.sizeValue <= 1000,
              'Above 1000 sqm' => property.sizeValue > 1000,
              _ => true,
            };

            if (!matchesLotSize) return false;
          }

          if (hasBudgetFilter) {
            final bool matchesBudget = switch (_selectedBudget) {
              'Below ₱1M' => property.priceValue < 1000000,
              '₱1M - ₱3M' =>
                property.priceValue >= 1000000 &&
                    property.priceValue <= 3000000,
              'Above ₱3M' => property.priceValue > 3000000,
              _ => true,
            };

            if (!matchesBudget) return false;
          }

          if (!hasSearchQuery) return true;

          final String normalizedTitle = _normalizeSearchText(property.title);
          final String normalizedLocation = _normalizeSearchText(
            property.location,
          );
          final String normalizedPrice = _normalizeSearchText(property.price);

          if (normalizedTitle.contains(normalizedQuery) ||
              normalizedLocation.contains(normalizedQuery) ||
              normalizedPrice.contains(normalizedQuery)) {
            return true;
          }

          if (numericQuery.isEmpty) return false;

          final String numericPrice = _digitsOnly(property.price);
          return numericPrice.contains(numericQuery);
        })
        .toList(growable: false);
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedLocation = null;
      _selectedLotSize = null;
      _selectedBudget = null;
    });
  }

  void _toggleSavedProperty(Property property) {
    if (!_savedProperties.contains(property) &&
        !appSubscriptionNotifier.value.isPremium &&
        _savedProperties.length >= freeSavedPropertiesLimit) {
      unawaited(_showSavedPropertiesUpgradePrompt());
      return;
    }

    setState(() {
      if (_savedProperties.contains(property)) {
        _savedProperties.remove(property);
        _savedPropertyIds.remove(property.id);
      } else {
        _savedProperties.add(property);
        _savedPropertyIds.add(property.id);
      }
    });
    unawaited(_persistSavedProperties());
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomeTab(
        properties: _filteredProperties,
        savedProperties: _savedProperties,
        onToggleSave: _toggleSavedProperty,
        searchController: _searchController,
        onSearchChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        selectedLocation: _selectedLocation,
        locationItems: _negrosPlaces
            .map((place) => place.placeName)
            .toSet()
            .toList()
          ..sort(),
        selectedLotSize: _selectedLotSize,
        selectedBudget: _selectedBudget,
        onLocationChanged: (value) {
          setState(() {
            _selectedLocation = value;
          });
        },
        onLotSizeChanged: (value) {
          setState(() {
            _selectedLotSize = value;
          });
        },
        onBudgetChanged: (value) {
          setState(() {
            _selectedBudget = value;
          });
        },
        onResetFilters: _resetFilters,
      ),
      const MapTab(),
      SavedTab(
        savedProperties: _savedProperties.toList(),
        onToggleSave: _toggleSavedProperty,
        subscription: appSubscriptionNotifier.value,
        onOpenSubscription: _openSubscriptionPage,
      ),
      const MessagesTab(),
      ProfileTab(
        profileImageBytes: _profileImageBytes,
        onAvatarTap: _showAvatarOptions,
      ),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Saved',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'Inbox',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  final List<Property> properties;
  final Set<Property> savedProperties;
  final ValueChanged<Property> onToggleSave;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? selectedLocation;
  final List<String> locationItems;
  final String? selectedLotSize;
  final String? selectedBudget;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<String?> onLotSizeChanged;
  final ValueChanged<String?> onBudgetChanged;
  final VoidCallback onResetFilters;

  const HomeTab({
    super.key,
    required this.properties,
    required this.savedProperties,
    required this.onToggleSave,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedLocation,
    required this.locationItems,
    required this.selectedLotSize,
    required this.selectedBudget,
    required this.onLocationChanged,
    required this.onLotSizeChanged,
    required this.onBudgetChanged,
    required this.onResetFilters,
  });

  @override
  Widget build(BuildContext context) {
    final List<Property> recommendedProperties = properties
        .take(6)
        .toList(growable: false);
    final List<Widget> activeFilterChips = <Widget>[
      if (selectedLocation != null)
        _ActiveFilterChip(
          label: selectedLocation!,
          onDeleted: () => onLocationChanged(null),
        ),
      if (selectedLotSize != null)
        _ActiveFilterChip(
          label: selectedLotSize!,
          onDeleted: () => onLotSizeChanged(null),
        ),
      if (selectedBudget != null)
        _ActiveFilterChip(
          label: selectedBudget!,
          onDeleted: () => onBudgetChanged(null),
        ),
    ];
    final bool hasSearchQuery = searchController.text.trim().isNotEmpty;
    final bool hasActiveFilters =
        hasSearchQuery || activeFilterChips.isNotEmpty;
    final String lotsHeaderTitle =
        hasActiveFilters ? 'Filtered Lots' : 'Available Lots';

    return SafeArea(
      child: CustomScrollView(
        cacheExtent: 400,
        slivers: [
            SliverAppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              floating: true,
              snap: true,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 84,
              flexibleSpace: const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: TopHeader(),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickySearchHeaderDelegate(
                height: 76,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SearchSection(
                    searchController: searchController,
                    onSearchChanged: onSearchChanged,
                    selectedLocation: selectedLocation,
                    locationItems: locationItems,
                    selectedLotSize: selectedLotSize,
                    selectedBudget: selectedBudget,
                    onLocationChanged: onLocationChanged,
                    onLotSizeChanged: onLotSizeChanged,
                    onBudgetChanged: onBudgetChanged,
                    onResetFilters: onResetFilters,
                  ),
                ),
              ),
            ),
            if (activeFilterChips.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...activeFilterChips,
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        label: const Text('Clear'),
                        onPressed: onResetFilters,
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Recommended Properties',
                  actionText: 'Reset',
                  onPressed: onResetFilters,
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (properties.isEmpty)
              const SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: EmptyState()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 20),
                sliver: SliverToBoxAdapter(
                  child: _RecommendedPropertiesCarousel(
                    properties: recommendedProperties,
                    savedProperties: savedProperties,
                    onToggleSave: onToggleSave,
                  ),
                ),
              ),
            if (properties.isNotEmpty) ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '$lotsHeaderTitle (${properties.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                sliver: SliverList.builder(
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final Property property = properties[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _PropertyTile(
                        property: property,
                        isSaved: savedProperties.contains(property),
                        onToggleSave: () => onToggleSave(property),
                      ),
                    );
                  },
                ),
              ),
            ],
        ],
      ),
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onDeleted;

  const _ActiveFilterChip({
    required this.label,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 180),
      child: InputChip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        deleteIcon: const Icon(Icons.close_rounded, size: 16),
        onDeleted: onDeleted,
      ),
    );
  }
}

class _StickySearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _StickySearchHeaderDelegate({
    required this.child,
    required this.height,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final ThemeData theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: theme.colorScheme.shadow.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchHeaderDelegate oldDelegate) {
    return height != oldDelegate.height || child != oldDelegate.child;
  }
}

class SavedTab extends StatelessWidget {
  final List<Property> savedProperties;
  final ValueChanged<Property> onToggleSave;
  final UserSubscription subscription;
  final VoidCallback onOpenSubscription;

  const SavedTab({
    super.key,
    required this.savedProperties,
    required this.onToggleSave,
    required this.subscription,
    required this.onOpenSubscription,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Saved Lots',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (!subscription.isPremium) ...[
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Free plan save limit'),
                  subtitle: Text(
                    'Save up to $freeSavedPropertiesLimit lots on Free. Upgrade for unlimited saved listings.',
                  ),
                  trailing: TextButton(
                    onPressed: onOpenSubscription,
                    child: const Text('Upgrade'),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: savedProperties.isEmpty
                  ? const EmptyState(
                      icon: Icons.favorite_border_rounded,
                      message: 'No saved lots yet.',
                      subtitle:
                          'Tap the heart on any listing to keep it here for quick access.',
                    )
                  : ListView.separated(
                      itemCount: savedProperties.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final property = savedProperties[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minVerticalPadding: 0,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 56,
                                height: 56,
                                child: _buildPropertyImage(
                                  context: context,
                                  property: property,
                                  height: 56,
                                  useThumbnail: true,
                                  fallbackChild: const Center(
                                    child: Icon(
                                      Icons.landscape_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              property.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  property.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    property.titleStatus,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ],
                            ),
                            trailing: Text(property.price),
                            onTap: () async {
                              await _precachePropertyImage(
                                context,
                                property,
                                height: 300,
                              );
                              if (!context.mounted) return;
                              Navigator.push(
                                context,
                                _instantRoute(
                                  PropertyDetailsPage(
                                    property: property,
                                    isSaved: true,
                                    onToggleSave: () => onToggleSave(property),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => _MessagesTabState();
}

class _InboxCardPalette {
  final Color background;
  final Color border;
  final Color accent;
  final Color avatarBackground;
  final Color avatarForeground;

  const _InboxCardPalette({
    required this.background,
    required this.border,
    required this.accent,
    required this.avatarBackground,
    required this.avatarForeground,
  });
}

class _ChatColorPalette {
  final Color scaffoldBackground;
  final Color appBarBackground;
  final Color appBarForeground;
  final Color avatarBackground;
  final Color avatarForeground;
  final Color outgoingBubble;
  final Color outgoingText;
  final Color incomingBubble;
  final Color incomingText;
  final Color composerFill;
  final Color sendButtonBackground;
  final Color sendButtonForeground;

  const _ChatColorPalette({
    required this.scaffoldBackground,
    required this.appBarBackground,
    required this.appBarForeground,
    required this.avatarBackground,
    required this.avatarForeground,
    required this.outgoingBubble,
    required this.outgoingText,
    required this.incomingBubble,
    required this.incomingText,
    required this.composerFill,
    required this.sendButtonBackground,
    required this.sendButtonForeground,
  });
}

class _MessagesTabState extends State<MessagesTab> {
  bool _isLoading = true;
  String? _errorText;
  List<ConversationSummary> _conversations = const [];
  String? _hoveredConversationButtonId;
  String? _pressedConversationButtonId;
  Timer? _inboxClockRefreshTimer;

  @override
  void initState() {
    super.initState();
    final List<ConversationSummary> cachedConversations =
        MessagingService.getCachedConversationSummaries();
    if (cachedConversations.isNotEmpty) {
      _conversations = cachedConversations;
      _isLoading = false;
    }
    _scheduleInboxClockRefresh();
    unawaited(_loadConversations(showLoader: cachedConversations.isEmpty));
  }

  @override
  void dispose() {
    _inboxClockRefreshTimer?.cancel();
    super.dispose();
  }

  void _scheduleInboxClockRefresh() {
    _inboxClockRefreshTimer?.cancel();

    final DateTime now = DateTime.now();
    final Duration delay = Duration(
      minutes: 1,
    ) -
    Duration(
      seconds: now.second,
      milliseconds: now.millisecond,
      microseconds: now.microsecond,
    );

    _inboxClockRefreshTimer = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleInboxClockRefresh();
    });
  }

  _InboxCardPalette _paletteForConversation(
    BuildContext context,
    ConversationSummary conversation,
  ) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return _InboxCardPalette(
      background: colorScheme.surface,
      border: colorScheme.outlineVariant,
      accent: colorScheme.primary,
      avatarBackground: colorScheme.surfaceContainerHighest,
      avatarForeground: colorScheme.onSurface,
    );
  }

  void _setHoveredConversationButton(String? conversationId) {
    if (_hoveredConversationButtonId == conversationId) return;
    setState(() {
      _hoveredConversationButtonId = conversationId;
    });
  }

  void _setPressedConversationButton(String? conversationId) {
    if (_pressedConversationButtonId == conversationId) return;
    setState(() {
      _pressedConversationButtonId = conversationId;
    });
  }

  Future<void> _loadConversations({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      final List<ConversationSummary> conversations =
          await MessagingService.fetchMyConversationSummaries();

      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _isLoading = false;
        _errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = 'Failed to load inbox.';
      });
    }
  }

  Future<void> _openConversation(ConversationSummary conversation) async {
    final int index = _conversations.indexWhere(
      (item) => item.id == conversation.id,
    );
    if (index != -1 && _conversations[index].isUnread) {
      setState(() {
        _conversations[index] = _conversations[index].copyWith(isUnread: false);
      });
      unawaited(MessagingService.markConversationAsRead(conversation.id));
    }

    await Navigator.push(
      context,
      _instantRoute(
        ChatPage(
          conversationId: conversation.id,
          senderName: conversation.otherParticipantName,
          initialMessages: MessagingService.getCachedConversationMessages(
            conversation.id,
            limit: MessagingService.initialMessagePageSize,
          ),
        ),
      ),
    );

    await _loadConversations(showLoader: false);
  }

  Future<bool> _confirmDeleteConversation(
    ConversationSummary conversation,
  ) async {
    final String displayTitle = _buyerInboxConversationTitle(conversation);
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete conversation'),
          content: Text(
            'Delete your conversation for "$displayTitle"? This will also remove its messages.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    return mounted && shouldDelete == true;
  }

  Future<void> _deleteConversation(ConversationSummary conversation) async {
    try {
      await MessagingService.deleteConversation(conversation.id);
      if (!mounted) return;

      setState(() {
        _conversations = _conversations
            .where((item) => item.id != conversation.id)
            .toList();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Conversation deleted.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete conversation: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inbox',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _loadConversations(showLoader: false),
                child: Builder(
                  builder: (context) {
                    if (_isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_errorText != null) {
                      return ListView(
                        children: [
                          const SizedBox(height: 120),
                          Center(
                            child: Text(
                              _errorText!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (_conversations.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('No messages yet.')),
                        ],
                      );
                    }

                    return ListView.separated(
                      itemCount: _conversations.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final ConversationSummary conversation =
                            _conversations[index];
                        return _buildMessageTile(context, conversation);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTile(
    BuildContext context,
    ConversationSummary conversation,
  ) {
    final String displayTitle = _buyerInboxConversationTitle(conversation);
    final _InboxCardPalette palette = _paletteForConversation(
      context,
      conversation,
    );
    final ImageProvider<Object>? propertyImageProvider =
        _buyerInboxConversationImageProvider(context, conversation);
    final bool isButtonHovered =
        _hoveredConversationButtonId == conversation.id;
    final bool isButtonPressed =
        _pressedConversationButtonId == conversation.id;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDeleteConversation(conversation),
      onDismissed: (_) {
        _deleteConversation(conversation);
      },
      background: const SizedBox.shrink(),
      secondaryBackground: const SizedBox.shrink(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: palette.background,
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: palette.border),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double thumbnailWidth = (constraints.maxWidth * 0.28)
                    .clamp(88.0, 112.0)
                    .toDouble();

                return SizedBox(
                  height: 88,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: thumbnailWidth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.avatarBackground,
                          ),
                          child: propertyImageProvider != null
                              ? Image(
                                  image: propertyImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : Center(
                                  child: Text(
                                    _messageInitial(displayTitle),
                                    style: TextStyle(
                                      color: palette.avatarForeground,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.15,
                                  fontWeight: conversation.isUnread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                              ),
                              MouseRegion(
                                onEnter: (_) =>
                                    _setHoveredConversationButton(
                                      conversation.id,
                                    ),
                                onExit: (_) {
                                  _setHoveredConversationButton(null);
                                  _setPressedConversationButton(null);
                                },
                                cursor: SystemMouseCursors.click,
                                child: Listener(
                                  onPointerDown: (_) =>
                                      _setPressedConversationButton(
                                        conversation.id,
                                      ),
                                  onPointerUp: (_) =>
                                      _setPressedConversationButton(null),
                                  onPointerCancel: (_) =>
                                      _setPressedConversationButton(null),
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 140),
                                    curve: Curves.easeOutCubic,
                                    scale: isButtonPressed
                                        ? 0.96
                                        : isButtonHovered
                                            ? 1.03
                                            : 1.0,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        boxShadow:
                                            isButtonHovered || isButtonPressed
                                                ? [
                                                    BoxShadow(
                                                      color: colorScheme.primary
                                                          .withValues(alpha: 0.14),
                                                      blurRadius: 14,
                                                      offset: const Offset(0, 6),
                                                    ),
                                                  ]
                                                : const [],
                                      ),
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          _setPressedConversationButton(null);
                                          _openConversation(conversation);
                                        },
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          minimumSize: const Size(0, 28),
                                          backgroundColor: isButtonHovered
                                              ? colorScheme.surfaceContainerHighest
                                              : colorScheme.surface,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          side: BorderSide(
                                            color: isButtonHovered
                                                ? colorScheme.primary.withValues(
                                                    alpha: 0.32,
                                                  )
                                                : colorScheme.outlineVariant,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          size: 13,
                                        ),
                                        label: const Text(
                                          'Chat Agent',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                if (conversation.isUnread) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  _formatInboxTimestamp(conversation.lastMessageAt),
                  style: TextStyle(
                    fontSize: 11,
                    color: conversation.isUnread
                        ? palette.accent
                        : colorScheme.onSurfaceVariant,
                    fontWeight: conversation.isUnread
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyerProfileData {
  final String displayName;
  final String email;
  final String phone;
  final UserSubscription subscription;

  const _BuyerProfileData({
    required this.displayName,
    required this.email,
    required this.phone,
    required this.subscription,
  });

  bool get isPremium => subscription.isPremium;
  String get planName => subscription.planName;
  DateTime? get expiresAt => subscription.expiresAt;

  _BuyerProfileData copyWith({
    String? displayName,
    String? email,
    String? phone,
    UserSubscription? subscription,
  }) {
    return _BuyerProfileData(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      subscription: subscription ?? this.subscription,
    );
  }
}

const _BuyerProfileData _defaultBuyerProfileData = _BuyerProfileData(
  displayName: 'Buyer',
  email: 'No email available',
  phone: 'No phone available',
  subscription: UserSubscription.free(),
);

String _profileTextValue(Object? value) {
  return value == null ? '' : value.toString().trim();
}

Future<_BuyerProfileData> _loadCurrentBuyerProfileData() async {
  final User? user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    return _defaultBuyerProfileData;
  }

  final UserSubscription localSubscription =
      await SubscriptionService.loadCurrentSubscription();

  try {
    final MessagingProfile? profile =
        await MessagingService.fetchCurrentProfile();
    final String profileName = _profileTextValue(profile?.fullName);
    final String metadataName = _profileTextValue(
      user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
    );
    final String displayName = profileName.isNotEmpty
        ? profileName
        : metadataName.isNotEmpty
        ? metadataName
        : _profileTextValue(user.email).isNotEmpty
        ? _profileTextValue(user.email)
        : _profileTextValue(user.phone).isNotEmpty
        ? _profileTextValue(user.phone)
        : 'Buyer';
    final String email = _profileTextValue(profile?.email).isNotEmpty
        ? _profileTextValue(profile?.email)
        : _profileTextValue(user.email);
    final String phone = _profileTextValue(profile?.phone).isNotEmpty
        ? _profileTextValue(profile?.phone)
        : _profileTextValue(user.phone);
    final UserSubscription subscription =
        profile?.subscription ?? localSubscription;

    return _BuyerProfileData(
      displayName: displayName,
      email: email.isNotEmpty ? email : 'No email available',
      phone: phone.isNotEmpty ? phone : 'No phone available',
      subscription: subscription,
    );
  } catch (_) {
    final String metadataName = _profileTextValue(
      user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
    );
    final String email = _profileTextValue(user.email);
    final String phone = _profileTextValue(user.phone);

    return _BuyerProfileData(
      displayName: metadataName.isNotEmpty
          ? metadataName
          : email.isNotEmpty
          ? email
          : phone.isNotEmpty
          ? phone
          : 'Buyer',
      email: email.isNotEmpty ? email : 'No email available',
      phone: phone.isNotEmpty ? phone : 'No phone available',
      subscription: localSubscription,
    );
  }
}

_BuyerProfileData _resolveBuyerProfileData(
  _BuyerProfileData? profile,
  UserSubscription currentSubscription,
) {
  final _BuyerProfileData baseProfile = profile ?? _defaultBuyerProfileData;
  final bool hasLocalSubscriptionData =
      currentSubscription.tier != SubscriptionTier.free ||
      currentSubscription.expiresAt != null;

  return baseProfile.copyWith(
    subscription: hasLocalSubscriptionData
        ? currentSubscription
        : baseProfile.subscription,
  );
}

Future<void> _signOutAndReturnToLogin(BuildContext context) async {
  try {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to log out. Please try again.')),
    );
  }
}

class ProfileTab extends StatefulWidget {
  final Uint8List? profileImageBytes;
  final VoidCallback onAvatarTap;

  const ProfileTab({
    super.key,
    required this.profileImageBytes,
    required this.onAvatarTap,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final Future<_BuyerProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadCurrentBuyerProfileData();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<UserSubscription>(
        valueListenable: appSubscriptionNotifier,
        builder: (context, currentSubscription, child) {
          return FutureBuilder<_BuyerProfileData>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final _BuyerProfileData profile = _resolveBuyerProfileData(
                snapshot.data,
                currentSubscription,
              );

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GestureDetector(
                          onTap: widget.onAvatarTap,
                          child: CircleAvatar(
                            radius: 48,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            backgroundImage: widget.profileImageBytes != null
                                ? MemoryImage(widget.profileImageBytes!)
                                : null,
                            child: widget.profileImageBytes == null
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: GestureDetector(
                            onTap: widget.onAvatarTap,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Real Estate Buyer Profile',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Account'),
                        subtitle: const Text('Personal contact details'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AccountPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.workspace_premium_outlined),
                        title: const Text('Subscription'),
                        subtitle: Text(
                          profile.isPremium
                              ? '${profile.planName} until ${_formatSubscriptionDate(profile.expiresAt)}'
                              : 'Current plan: ${profile.planName}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SubscriptionPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('Settings'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsPage(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: const Text('Log Out'),
                        textColor: Colors.red,
                        onTap: () async {
                          await _signOutAndReturnToLogin(context);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final Future<_BuyerProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadCurrentBuyerProfileData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account'), centerTitle: true),
      body: ValueListenableBuilder<UserSubscription>(
        valueListenable: appSubscriptionNotifier,
        builder: (context, currentSubscription, child) {
          return FutureBuilder<_BuyerProfileData>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final _BuyerProfileData profile = _resolveBuyerProfileData(
                snapshot.data,
                currentSubscription,
              );

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: const Text('Name'),
                        subtitle: Text(profile.displayName),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('Email'),
                        subtitle: Text(profile.email),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('Phone'),
                        subtitle: Text(profile.phone),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.workspace_premium_outlined),
                        title: const Text('Subscription'),
                        subtitle: Text(
                          profile.isPremium
                              ? '${profile.planName} until ${_formatSubscriptionDate(profile.expiresAt)}'
                              : 'Current plan: ${profile.planName}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SubscriptionPage(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String senderName;
  final List<ConversationMessage> initialMessages;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.senderName,
    this.initialMessages = const [],
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _messagesScrollController = ScrollController();
  bool _isLoading = true;
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  String? _errorText;
  List<ConversationMessage> _messages = const [];
  RealtimeChannel? _messagesChannel;

  String get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id ?? '';

  _ChatColorPalette _chatPalette(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return _ChatColorPalette(
      scaffoldBackground: theme.scaffoldBackgroundColor,
      appBarBackground:
          theme.appBarTheme.backgroundColor ?? colorScheme.surface,
      appBarForeground:
          theme.appBarTheme.foregroundColor ?? colorScheme.onSurface,
      avatarBackground: colorScheme.primaryContainer,
      avatarForeground: colorScheme.onPrimaryContainer,
      outgoingBubble: colorScheme.primaryContainer,
      outgoingText: colorScheme.onPrimaryContainer,
      incomingBubble: colorScheme.surfaceContainerHighest,
      incomingText: colorScheme.onSurface,
      composerFill: theme.cardColor,
      sendButtonBackground: colorScheme.primary,
      sendButtonForeground: colorScheme.onPrimary,
    );
  }

  @override
  void initState() {
    super.initState();
    _messages = List<ConversationMessage>.from(widget.initialMessages);
    _isLoading = _messages.isEmpty;
    _hasMoreMessages =
        _messages.length >= MessagingService.initialMessagePageSize;
    _messagesScrollController.addListener(_handleMessagesScroll);
    _subscribeToMessageUpdates();
    if (_messages.isNotEmpty) {
      _jumpToBottom();
    }
    unawaited(MessagingService.markConversationAsRead(widget.conversationId));
    unawaited(
      _loadMessages(showLoader: _messages.isEmpty, scrollToBottom: true),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _messagesScrollController.dispose();
    if (_messagesChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(_messagesChannel!));
    }
    super.dispose();
  }

  void _subscribeToMessageUpdates() {
    _messagesChannel = Supabase.instance.client
        .channel('buyer-chat-${widget.conversationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: widget.conversationId,
          ),
          callback: (_) {
            if (!mounted) return;
            unawaited(
              MessagingService.markConversationAsRead(widget.conversationId),
            );
            unawaited(_loadMessages(showLoader: false, scrollToBottom: true));
          },
        )
        .subscribe();
  }

  void _handleMessagesScroll() {
    if (!_messagesScrollController.hasClients ||
        _isLoadingMore ||
        !_hasMoreMessages ||
        _messages.isEmpty) {
      return;
    }

    if (_messagesScrollController.position.pixels <= 120) {
      unawaited(_loadOlderMessages());
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) return;
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) return;
      _messagesScrollController.jumpTo(
        _messagesScrollController.position.maxScrollExtent,
      );
    });
  }

  List<ConversationMessage> _mergeMessages(
    Iterable<ConversationMessage> existing,
    Iterable<ConversationMessage> incoming,
  ) {
    final Map<String, ConversationMessage> byId =
        <String, ConversationMessage>{};
    for (final ConversationMessage message in existing) {
      byId[message.id] = message;
    }
    for (final ConversationMessage message in incoming) {
      byId[message.id] = message;
    }

    final List<ConversationMessage> merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  Future<void> _loadMessages({
    bool showLoader = true,
    bool scrollToBottom = false,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });
    }

    try {
      final List<ConversationMessage> messages =
          await MessagingService.fetchConversationMessages(
            widget.conversationId,
            limit: MessagingService.initialMessagePageSize,
          );
      final int previousCount = _messages.length;
      final List<ConversationMessage> mergedMessages = _mergeMessages(
        _messages,
        messages,
      );

      if (!mounted) return;
      setState(() {
        _messages = mergedMessages;
        _isLoading = false;
        _errorText = null;
        _isSending = false;
        _hasMoreMessages =
            messages.length >= MessagingService.initialMessagePageSize;
      });
      if (scrollToBottom || mergedMessages.length > previousCount) {
        if (previousCount == 0) {
          _jumpToBottom();
        } else {
          _scrollToBottom();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSending = false;
        _errorText = 'Failed to load messages.';
      });
    }
  }

  Future<void> _loadOlderMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;

    final DateTime before = _messages.first.createdAt;
    final double previousOffset = _messagesScrollController.hasClients
        ? _messagesScrollController.offset
        : 0;
    final double previousMaxExtent = _messagesScrollController.hasClients
        ? _messagesScrollController.position.maxScrollExtent
        : 0;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final List<ConversationMessage> olderMessages =
          await MessagingService.fetchConversationMessages(
            widget.conversationId,
            limit: MessagingService.initialMessagePageSize,
            before: before,
          );
      final List<ConversationMessage> mergedMessages = _mergeMessages(
        _messages,
        olderMessages,
      );

      if (!mounted) return;
      setState(() {
        _messages = mergedMessages;
        _isLoadingMore = false;
        _hasMoreMessages =
            olderMessages.length >= MessagingService.initialMessagePageSize;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_messagesScrollController.hasClients) return;
        final double delta =
            _messagesScrollController.position.maxScrollExtent -
            previousMaxExtent;
        _messagesScrollController.jumpTo(previousOffset + delta);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final String text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    final ConversationMessage optimisticMessage = ConversationMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      conversationId: widget.conversationId,
      senderId: _currentUserId,
      body: text,
      createdAt: DateTime.now(),
      readAt: null,
    );

    setState(() {
      _isSending = true;
      _errorText = null;
      _messages = [..._messages, optimisticMessage];
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      final ConversationMessage sentMessage =
          await MessagingService.sendMessage(
            conversationId: widget.conversationId,
            body: text,
          );
      if (!mounted) return;
      final List<ConversationMessage> currentMessages = _messages
          .where((message) => message.id != optimisticMessage.id)
          .toList();
      setState(() {
        _isSending = false;
        _messages = _mergeMessages(currentMessages, [sentMessage]);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _errorText = 'Failed to send message.';
        _messages = _messages
            .where((message) => message.id != optimisticMessage.id)
            .toList();
        _messageController.text = text;
      });
    }
  }

  Future<void> _showMessageActions(ConversationMessage message) async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || action == null) return;

    if (action == 'edit') {
      await _editMessage(message);
    } else if (action == 'delete') {
      await _deleteMessage(message);
    }
  }

  Future<void> _editMessage(ConversationMessage message) async {
    final TextEditingController controller = TextEditingController(
      text: message.body,
    );

    final String? updatedText = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit message'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Update your message'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (!mounted || updatedText == null || updatedText.isEmpty) return;
    if (updatedText == message.body.trim()) return;

    try {
      await MessagingService.updateMessage(
        messageId: message.id,
        body: updatedText,
      );
      await _loadMessages(showLoader: false, scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to edit message: $e')));
    }
  }

  Future<void> _deleteMessage(ConversationMessage message) async {
    final bool shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Delete message'),
              content: const Text(
                'This message will be removed from the chat.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!mounted || !shouldDelete) return;

    try {
      await MessagingService.deleteMessage(message.id);
      await _loadMessages(showLoader: false, scrollToBottom: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete message: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final _ChatColorPalette palette = _chatPalette(context);

    return Scaffold(
      backgroundColor: palette.scaffoldBackground,
      appBar: AppBar(
        backgroundColor: palette.appBarBackground,
        foregroundColor: palette.appBarForeground,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: palette.avatarBackground,
              foregroundColor: palette.avatarForeground,
              child: Text(
                widget.senderName[0],
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Text(widget.senderName, style: const TextStyle(fontSize: 18)),
          ],
        ),
        titleSpacing: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                if (_isLoading && _messages.isEmpty) {
                  return const _ChatLoadingPlaceholder();
                }

                if (_errorText != null && _messages.isEmpty) {
                  return Center(
                    child: Text(
                      _errorText!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }

                if (_messages.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('No messages yet.')),
                    ],
                  );
                }

                return ListView.builder(
                  controller: _messagesScrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_isLoadingMore && index == 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final int messageIndex = _isLoadingMore ? index - 1 : index;
                    final ConversationMessage msg = _messages[messageIndex];
                    final bool isMe = msg.isFrom(_currentUserId);
                    final Color bubbleColor = isMe
                        ? palette.outgoingBubble
                        : palette.incomingBubble;
                    final Color textColor = isMe
                        ? palette.outgoingText
                        : palette.incomingText;
                    return Align(
                      alignment: isMe
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: GestureDetector(
                        onLongPress: isMe && !msg.isPending
                            ? () => _showMessageActions(msg)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.circular(16).copyWith(
                              bottomRight: isMe
                                  ? const Radius.circular(0)
                                  : const Radius.circular(16),
                              bottomLeft: !isMe
                                  ? const Radius.circular(0)
                                  : const Radius.circular(16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.body,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(height: 6),
                                Text(
                                  msg.isPending ? 'Sending...' : 'Sent',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textColor.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_errorText != null && _messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: palette.composerFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: palette.sendButtonBackground,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      child: _isSending
                          ? SizedBox(
                              key: const ValueKey('sending'),
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  palette.sendButtonForeground,
                                ),
                              ),
                            )
                          : IconButton(
                              key: const ValueKey('send'),
                              icon: Icon(
                                Icons.send_rounded,
                                color: palette.sendButtonForeground,
                              ),
                              onPressed: _sendMessage,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatLoadingPlaceholder extends StatelessWidget {
  const _ChatLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    final Color baseColor = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: List<Widget>.generate(6, (index) {
        final bool isOutgoing = index.isOdd;
        return Align(
          alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: isOutgoing ? 220 : 180,
            height: 54,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(16).copyWith(
                bottomRight: isOutgoing
                    ? const Radius.circular(0)
                    : const Radius.circular(16),
                bottomLeft: !isOutgoing
                    ? const Radius.circular(0)
                    : const Radius.circular(16),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  late bool _darkModeEnabled;
  bool _notifyNewProperties = true;
  bool _notifyPriceDrops = true;
  bool _notifyMessages = true;
  double _currentFontSizeScale = 1.0; // Default font size scale

  @override
  void initState() {
    super.initState();
    _darkModeEnabled = appThemeNotifier.value == ThemeMode.dark;
    _currentFontSizeScale = appFontScaleNotifier.value;
  }

  Widget _buildCompactSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool dense = false,
  }) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color activeSwitchColor = isDarkMode
        ? const Color(0xFF7DD3FC)
        : Theme.of(context).colorScheme.primary;
    return SwitchListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      value: value,
      dense: dense,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onChanged: onChanged,
      activeThumbColor: activeSwitchColor,
      controlAffinity: ListTileControlAffinity.trailing,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final Color activeSwitchColor = isDarkMode
        ? const Color(0xFF7DD3FC)
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        children: [
          Theme(
            data: Theme.of(context).copyWith(
              switchTheme: SwitchThemeData(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                thumbColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return activeSwitchColor;
                  }
                  return null;
                }),
                trackColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return activeSwitchColor.withValues(alpha: 0.42);
                  }
                  return null;
                }),
              ),
            ),
            child: Column(
              children: [
                Transform.scale(
                  scale: 0.76,
                  alignment: Alignment.centerRight,
                  child: _buildCompactSwitchTile(
                    title: 'Push Notifications',
                    subtitle: 'Receive alerts for new lots',
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                ),
                // Font Sizing Feature
                ListTile(
                  title: const Text('Font Size'),
                  subtitle: Text(
                    'Adjust text size for better readability (${_currentFontSizeScale.toStringAsFixed(1)}x)',
                  ),
                  leading: const Icon(Icons.format_size),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 72,
                    right: 20,
                  ),
                  child: Slider(
                    value: _currentFontSizeScale,
                    min: 0.8,
                    max: 1.5,
                    divisions:
                        7, // Allows for 0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5
                    label: _currentFontSizeScale.toStringAsFixed(1),
                    onChanged: (double value) {
                      setState(() {
                        _currentFontSizeScale = value;
                        appFontScaleNotifier.value = value;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 8.0,
                  ),
                  child: Text(
                    'This is an example text. Adjust the slider above to see the font size change.',
                    textScaler: TextScaler.linear(_currentFontSizeScale),
                  ),
                ),
                if (_notificationsEnabled)
                  Padding(
                    padding: const EdgeInsets.only(left: 32.0),
                    child: Column(
                      children: [
                        Transform.scale(
                          scale: 0.76,
                          alignment: Alignment.centerRight,
                          child: _buildCompactSwitchTile(
                            title: 'New Lot Alerts',
                            value: _notifyNewProperties,
                            dense: true,
                            onChanged: (value) {
                              setState(() => _notifyNewProperties = value);
                            },
                          ),
                        ),
                        Transform.scale(
                          scale: 0.76,
                          alignment: Alignment.centerRight,
                          child: _buildCompactSwitchTile(
                            title: 'Price Drops on Saved',
                            value: _notifyPriceDrops,
                            dense: true,
                            onChanged: (value) {
                              setState(() => _notifyPriceDrops = value);
                            },
                          ),
                        ),
                        Transform.scale(
                          scale: 0.76,
                          alignment: Alignment.centerRight,
                          child: _buildCompactSwitchTile(
                            title: 'Agent Messages',
                            value: _notifyMessages,
                            dense: true,
                            onChanged: (value) {
                              setState(() => _notifyMessages = value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                Transform.scale(
                  scale: 0.76,
                  alignment: Alignment.centerRight,
                  child: _buildCompactSwitchTile(
                    title: 'Dark Mode',
                    subtitle: 'Switch to a darker theme',
                    value: _darkModeEnabled,
                    onChanged: (value) {
                      setState(() {
                        _darkModeEnabled = value;
                        appThemeNotifier.value = value
                            ? ThemeMode.dark
                            : ThemeMode.light;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Reset Password'),
            subtitle: const Text('Change password for this account'),
            leading: const Icon(Icons.lock_reset),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ChangePasswordPage(),
                ),
              );
            },
          ),
          ValueListenableBuilder<String?>(
            valueListenable: appPinCodeNotifier,
            builder: (context, pinCode, child) {
              return ListTile(
                title: const Text('PIN Code'),
                subtitle: Text(
                  pinCode == null ? 'Set a 4-digit PIN' : 'PIN is configured',
                ),
                leading: const Icon(Icons.pin_outlined),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => PinCodePage()),
                  );
                },
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Help & Support'),
            leading: const Icon(Icons.help_outline),
            onTap: () {},
          ),
          ListTile(
            title: const Text('About'),
            leading: const Icon(Icons.info_outline),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const String _devAgentShortcutUsername = '1q1q';
  static const String _devAgentShortcutPassword = '1q1q';
  static const String _devAgentEmail = String.fromEnvironment(
    'DEV_AGENT_EMAIL',
  );
  static const String _devAgentPassword = String.fromEnvironment(
    'DEV_AGENT_PASSWORD',
  );
  static const String _devUserShortcutUsername = '2q2q';
  static const String _devUserShortcutPassword = '2q2q';
  static const String _devUserEmail = String.fromEnvironment('DEV_USER_EMAIL');
  static const String _devUserPassword = String.fromEnvironment(
    'DEV_USER_PASSWORD',
  );

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorText;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isRouting = false;
  bool _isOpeningPasswordRecovery = false;

  bool get _hasDevAgentCredentials =>
      _devAgentEmail.isNotEmpty && _devAgentPassword.isNotEmpty;

  bool get _hasDevUserCredentials =>
      _devUserEmail.isNotEmpty && _devUserPassword.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        unawaited(_openPasswordRecoveryPage());
        return;
      }

      if (data.event == AuthChangeEvent.signedIn) {
        unawaited(_routeToAuthenticatedUser(data.session?.user));
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _routeToAuthenticatedUser(User? user) async {
    if (user == null || !mounted || _isRouting || _isOpeningPasswordRecovery) {
      return;
    }

    _isRouting = true;
    try {
      await _routeByRole(user);
    } finally {
      if (mounted) {
        _isRouting = false;
      }
    }
  }

  Future<void> _openPasswordRecoveryPage() async {
    if (!mounted || _isOpeningPasswordRecovery) return;

    _isOpeningPasswordRecovery = true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const ChangePasswordPage(isPasswordRecovery: true),
      ),
    );

    if (mounted) {
      _isOpeningPasswordRecovery = false;
    }
  }

  Future<void> _routeByRole(User user) async {
    appThemeNotifier.value = ThemeMode.light;

    final role =
        ((user.appMetadata['role'] ?? user.userMetadata?['role']) as String?)
            ?.toLowerCase() ??
        'user';

    await loadProperties();

    if (!mounted) return;
    if (role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AdminHomePage(onLogout: _signOutAndReturnToLogin),
        ),
      );
    } else {
      final List<Property> initialProperties = appPropertiesNotifier.value
          .take(_initialPropertyImagePrefetchCount)
          .toList(growable: false);
      await Future.wait(
        initialProperties.map(
          (property) =>
              _precachePropertyImage(context, property, useThumbnail: true),
        ),
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  Future<void> _signInWithDevUserShortcut() async {
    try {
      final AuthResponse response = await Supabase.instance.client.auth
          .signInWithPassword(email: _devUserEmail, password: _devUserPassword);
      await _routeToAuthenticatedUser(response.user);
      return;
    } on AuthException catch (error) {
      final String message = error.message.toLowerCase();
      final bool shouldCreateAccount =
          message.contains('invalid login credentials') ||
          message.contains('user not found');

      if (!shouldCreateAccount) rethrow;
    }

    await Supabase.instance.client.auth.signUp(
      email: _devUserEmail,
      password: _devUserPassword,
      data: const {'role': 'user'},
    );

    final AuthResponse response = await Supabase.instance.client.auth
        .signInWithPassword(email: _devUserEmail, password: _devUserPassword);
    await _routeToAuthenticatedUser(response.user);
  }

  Future<void> _signIn() async {
    final enteredEmail = _emailController.text.trim();
    final enteredPassword = _passwordController.text;
    final bool requestedDevAgentShortcut =
        enteredEmail == _devAgentShortcutUsername &&
        enteredPassword == _devAgentShortcutPassword;
    final bool requestedDevUserShortcut =
        enteredEmail == _devUserShortcutUsername &&
        enteredPassword == _devUserShortcutPassword;

    final bool isDevAgentShortcut =
        requestedDevAgentShortcut && _hasDevAgentCredentials;
    final bool isDevUserShortcut =
        requestedDevUserShortcut && _hasDevUserCredentials;

    if (requestedDevAgentShortcut && !_hasDevAgentCredentials) {
      setState(() {
        _errorText =
            'Dev agent shortcut is disabled until DEV_AGENT_EMAIL and '
            'DEV_AGENT_PASSWORD are provided.';
      });
      return;
    }

    if (requestedDevUserShortcut && !_hasDevUserCredentials) {
      setState(() {
        _errorText =
            'Dev user shortcut is disabled until DEV_USER_EMAIL and '
            'DEV_USER_PASSWORD are provided.';
      });
      return;
    }

    if (isDevUserShortcut) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });

      try {
        await _signInWithDevUserShortcut();
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() {
          _errorText = e.message;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _errorText = 'Dev user login failed. Please try again.';
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    final email = isDevAgentShortcut ? _devAgentEmail : enteredEmail;
    final password = isDevAgentShortcut ? _devAgentPassword : enteredPassword;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Please enter email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await _routeToAuthenticatedUser(response.user);
    } on AuthException catch (e) {
      if (!mounted) return;
      final String normalizedMessage = e.message.toLowerCase();
      setState(() {
        _errorText = normalizedMessage.contains('email rate limit exceeded')
            ? 'Too many signup attempts for now. The account may already exist, so try Login first. If it fails, wait a bit before signing up again.'
            : e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Login failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorText = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : _authRedirectUrl,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Google sign-in failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _KsnHeaderLogo(size: 88),
                  const SizedBox(height: 12),
                  Text(
                    'Kogihan Sa Negros',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'finding you an asset that fits your budget',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 6,
                    shadowColor: Colors.black12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              hintText: 'Email',
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Theme.of(context).cardColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          if (_errorText != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _errorText!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Login'),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isGoogleLoading
                                  ? null
                                  : _signInWithGoogle,
                              icon: _isGoogleLoading
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const _GoogleLogoIcon(),
                              label: const Text('Continue with Google'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const SignUpPage(),
                                    ),
                                  );
                                },
                                child: const Text('Sign up'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const ForgotPasswordPage(),
                                    ),
                                  );
                                },
                                child: const Text('Recover access'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleLogoIcon extends StatelessWidget {
  const _GoogleLogoIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      width: 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            'G',
            style: TextStyle(
              color: const Color(0xFF4285F4),
              fontSize: 23,
              fontWeight: FontWeight.w800,
              height: 1,
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
          ),
          Positioned(
            right: 1,
            bottom: 5,
            child: Container(
              height: 5,
              width: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF34A853),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(5),
                  bottomLeft: Radius.circular(5),
                ),
              ),
            ),
          ),
          Positioned(
            left: 2,
            bottom: 3,
            child: Transform.rotate(
              angle: -0.55,
              child: Container(
                height: 5,
                width: 10,
                color: const Color(0xFFFBBC05),
              ),
            ),
          ),
          Positioned(
            left: 2,
            top: 4,
            child: Transform.rotate(
              angle: 0.55,
              child: Container(
                height: 5,
                width: 10,
                color: const Color(0xFFEA4335),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePasswordComplexity(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must include at least one uppercase letter.';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must include at least one lowercase letter.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must include at least one number.';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must include at least one symbol.';
    }

    return null;
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorText = 'Please enter email and password.';
      });
      return;
    }

    final passwordError = _validatePasswordComplexity(password);
    if (passwordError != null) {
      setState(() {
        _errorText = passwordError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: const {'role': 'user'},
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created. Please verify your email before logging in.',
          ),
        ),
      );
      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Sign up failed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Sign Up')),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 86,
                          width: 86,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              height: 64,
                              width: 64,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_add_alt_1_outlined,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Create your account',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign up to save lots, contact agents, and manage your property search.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF667085),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          hintText: 'name@example.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4E7EC),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) {
                          if (!_isLoading) _signUp();
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4E7EC),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use 8+ characters with uppercase, lowercase, number, and symbol.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF667085),
                          height: 1.35,
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFDA29B),
                            ),
                          ),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(color: Color(0xFFB42318)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signUp,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Sign Up'),
                        ),
                      ),
                    ],
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

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  Timer? _resetCountdownTimer;
  bool _isLoading = false;
  bool _emailSent = false;
  int _resetCountdown = 0;
  String? _errorText;

  @override
  void dispose() {
    _resetCountdownTimer?.cancel();
    _emailController.dispose();
    super.dispose();
  }

  void _startResetCountdown() {
    _resetCountdownTimer?.cancel();
    setState(() {
      _emailSent = true;
      _resetCountdown = 60;
    });

    _resetCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resetCountdown <= 1) {
        timer.cancel();
        setState(() {
          _resetCountdown = 0;
        });
        return;
      }

      setState(() {
        _resetCountdown--;
      });
    });
  }

  Future<void> _sendResetEmail() async {
    if (_resetCountdown > 0) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        _errorText = 'Please enter your email.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: _authRedirectUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset email sent. Check your inbox.'),
        ),
      );
      _startResetCountdown();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Failed to send reset email. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 86,
                          width: 86,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              height: 64,
                              width: 64,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_outline,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Forgot your password?',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enter your email and we will send you a secure reset link.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF667085),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) {
                          if (!_isLoading && _resetCountdown == 0) {
                            _sendResetEmail();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          hintText: 'name@example.com',
                          prefixIcon: const Icon(Icons.email_outlined),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4E7EC),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFDA29B),
                            ),
                          ),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(color: Color(0xFFB42318)),
                          ),
                        ),
                      ],
                      if (_emailSent && _errorText == null) ...[
                        const SizedBox(height: 14),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF3),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFABEFC6),
                              ),
                            ),
                            child: Text(
                              _resetCountdown > 0
                                  ? 'Reset link sent. Check your inbox.'
                                  : 'Reset link sent. You can resend now.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF067647),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading || _resetCountdown > 0
                              ? null
                              : _sendResetEmail,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : _resetCountdown > 0
                              ? Text('Resend in ${_resetCountdown}s')
                              : const Text('Send Reset Email'),
                        ),
                      ),
                    ],
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

class ChangePasswordPage extends StatefulWidget {
  final bool isPasswordRecovery;

  const ChangePasswordPage({
    super.key,
    this.isPasswordRecovery = false,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorText;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _validatePasswordComplexity(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must include at least one uppercase letter.';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must include at least one lowercase letter.';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must include at least one number.';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must include at least one symbol.';
    }

    return null;
  }

  Future<void> _changePassword() async {
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        _errorText = 'Please enter and confirm your new password.';
      });
      return;
    }

    final passwordError = _validatePasswordComplexity(newPassword);
    if (passwordError != null) {
      setState(() {
        _errorText = passwordError;
      });
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() {
        _errorText = 'Passwords do not match.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );

      if (widget.isPasswordRecovery) {
        await Supabase.instance.client.auth.signOut();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
        return;
      }

      Navigator.pop(context);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Failed to update password. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    final user = Supabase.instance.client.auth.currentUser;
    final String pageTitle =
        widget.isPasswordRecovery ? 'Create New Password' : 'Reset Password';
    final String heading = widget.isPasswordRecovery
        ? 'Create a new password'
        : 'Update your password';
    final String helperText = widget.isPasswordRecovery
        ? 'Choose a secure password for your account.'
        : 'Change the password for your current account.';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(title: Text(pageTitle)),
      body: SafeArea(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 24,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 86,
                          width: 86,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Container(
                              height: 64,
                              width: 64,
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_reset_outlined,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        heading,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF101828),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        helperText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF667085),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE4E7EC),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.alternate_email,
                              color: Color(0xFF667085),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user?.email ?? 'Logged in account',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF475467),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscureNewPassword,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureNewPassword = !_obscureNewPassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4E7EC),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Use 8+ characters with uppercase, lowercase, number, and symbol.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF667085),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: (_) {
                          if (!_isLoading) _changePassword();
                        },
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: const Icon(Icons.verified_user_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(
                              color: Color(0xFFE4E7EC),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide(
                              color: colorScheme.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (_errorText != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F3),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: const Color(0xFFFDA29B),
                            ),
                          ),
                          child: Text(
                            _errorText!,
                            style: const TextStyle(color: Color(0xFFB42318)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _changePassword,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Update Password'),
                        ),
                      ),
                    ],
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

class _KsnHeaderLogo extends StatelessWidget {
  final double size;

  const _KsnHeaderLogo({this.size = 48});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.29),
        boxShadow: [
          BoxShadow(
            color: isLightTheme
                ? theme.colorScheme.shadow.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Image.asset(
        'asset/ksn_logo.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return CustomPaint(painter: _KsnLogoPainter());
        },
      ),
    );
  }
}

class _KsnLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint backgroundPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF243F92), Color(0xFF070E2F)],
      ).createShader(rect);
    canvas.drawRect(rect, backgroundPaint);

    final double width = size.width;
    final double height = size.height;
    final Color gold = const Color(0xFFC9BE57);
    final Paint goldStroke = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final Paint darkFill = Paint()..color = const Color(0xFF10235F);

    final Path tower = Path()
      ..moveTo(width * 0.60, height * 0.22)
      ..lineTo(width * 0.75, height * 0.14)
      ..lineTo(width * 0.75, height * 0.48)
      ..lineTo(width * 0.60, height * 0.42)
      ..close();
    canvas.drawPath(tower, darkFill);
    canvas.drawPath(tower, goldStroke);

    final Path roof = Path()
      ..moveTo(width * 0.18, height * 0.53)
      ..lineTo(width * 0.50, height * 0.32)
      ..lineTo(width * 0.82, height * 0.53);
    canvas.drawPath(roof, goldStroke);

    final Path roofSweep = Path()
      ..moveTo(width * 0.14, height * 0.61)
      ..quadraticBezierTo(
        width * 0.50,
        height * 0.53,
        width * 0.88,
        height * 0.61,
      );
    canvas.drawPath(roofSweep, goldStroke);

    final Paint windowPaint = Paint()..color = gold;
    final double windowSize = width * 0.055;
    for (final Offset offset in <Offset>[
      Offset(width * 0.44, height * 0.48),
      Offset(width * 0.51, height * 0.48),
      Offset(width * 0.44, height * 0.56),
      Offset(width * 0.51, height * 0.56),
    ]) {
      canvas.drawRect(offset & Size(windowSize, windowSize), windowPaint);
    }

    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: 'KSN',
        style: TextStyle(
          color: gold,
          fontSize: width * 0.25,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    textPainter.paint(
      canvas,
      Offset((width - textPainter.width) / 2, height * 0.66),
    );
  }

  @override
  bool shouldRepaint(covariant _KsnLogoPainter oldDelegate) => false;
}

class TopHeader extends StatelessWidget {
  const TopHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;

    return Row(
      children: [
        const _KsnHeaderLogo(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kogihan Sa Negros',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Explore premium lots and investment-ready land.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isLightTheme
                ? Color.alphaBlend(
                    theme.colorScheme.primary.withValues(alpha: 0.04),
                    theme.cardColor,
                  )
                : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: isLightTheme
                    ? theme.colorScheme.shadow.withValues(alpha: 0.06)
                    : const Color(0x14000000),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.notifications_none_rounded),
        ),
      ],
    );
  }
}

class SearchSection extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? selectedLocation;
  final List<String> locationItems;
  final String? selectedLotSize;
  final String? selectedBudget;
  final ValueChanged<String?> onLocationChanged;
  final ValueChanged<String?> onLotSizeChanged;
  final ValueChanged<String?> onBudgetChanged;
  final VoidCallback onResetFilters;

  const SearchSection({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedLocation,
    required this.locationItems,
    required this.selectedLotSize,
    required this.selectedBudget,
    required this.onLocationChanged,
    required this.onLotSizeChanged,
    required this.onBudgetChanged,
    required this.onResetFilters,
  });

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Filters',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                FilterDropdown(
                  label: 'Location',
                  value: selectedLocation,
                  items: locationItems,
                  onChanged: onLocationChanged,
                ),
                const SizedBox(height: 12),
                FilterDropdown(
                  label: 'Lot Size',
                  value: selectedLotSize,
                  items: const [
                    'Below 500 sqm',
                    '500 - 1000 sqm',
                    'Above 1000 sqm',
                  ],
                  onChanged: onLotSizeChanged,
                ),
                const SizedBox(height: 12),
                FilterDropdown(
                  label: 'Budget',
                  value: selectedBudget,
                  items: const ['Below ₱1M', '₱1M - ₱3M', 'Above ₱3M'],
                  onChanged: onBudgetChanged,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          onResetFilters();
                          Navigator.pop(sheetContext);
                        },
                        child: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;
    final int activeFilterCount = [
      selectedLocation,
      selectedLotSize,
      selectedBudget,
    ].where((value) => value != null).length;
    final Color searchSurface = isLightTheme
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.035),
            theme.colorScheme.surface,
          )
        : const Color(0xFFF1F4F6);
    final Color searchShadow = isLightTheme
        ? theme.colorScheme.shadow.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final Color textColor = isLightTheme
        ? theme.colorScheme.onSurface
        : const Color(0xFF1F2933);
    final Color mutedColor = isLightTheme
        ? theme.colorScheme.onSurfaceVariant
        : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: searchSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: searchShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        onChanged: onSearchChanged,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search by city, barangay, or price',
          hintStyle: TextStyle(
            color: mutedColor,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(Icons.search, color: mutedColor),
          suffixIcon: IconButton(
            tooltip: 'Filters',
            onPressed: () => _showFilterSheet(context),
            icon: Badge(
              isLabelVisible: activeFilterCount > 0,
              label: Text(activeFilterCount.toString()),
              child: Icon(Icons.tune_rounded, color: mutedColor),
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class FilterDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final ThemeData theme = Theme.of(context);
    final Color dropdownSurface = isLightTheme
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.03),
            theme.colorScheme.surface,
          )
        : theme.cardColor;
    final Color dropdownShadow = isLightTheme
        ? theme.colorScheme.shadow.withValues(alpha: 0.05)
        : Colors.transparent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: dropdownSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isLightTheme
            ? [
                BoxShadow(
                  color: dropdownShadow,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        onChanged: onChanged,
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: isLightTheme
              ? theme.colorScheme.onSurfaceVariant
              : theme.iconTheme.color,
        ),
        style: TextStyle(
          color: isLightTheme
              ? theme.colorScheme.onSurface
              : theme.textTheme.bodyMedium?.color,
          fontWeight: FontWeight.w500,
        ),
        dropdownColor: theme.cardColor,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isLightTheme
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback? onPressed;

  const SectionHeader({
    super.key,
    required this.title,
    required this.actionText,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(actionText)),
      ],
    );
  }
}

class _RecommendedPropertiesCarousel extends StatefulWidget {
  final List<Property> properties;
  final Set<Property> savedProperties;
  final ValueChanged<Property> onToggleSave;

  const _RecommendedPropertiesCarousel({
    required this.properties,
    required this.savedProperties,
    required this.onToggleSave,
  });

  @override
  State<_RecommendedPropertiesCarousel> createState() =>
      _RecommendedPropertiesCarouselState();
}

class _RecommendedPropertiesCarouselState
    extends State<_RecommendedPropertiesCarousel> {
  late final CarouselController _carouselController;
  int _currentPage = 0;
  static const List<int> _carouselWeights = <int>[1];
  static const double _activeCardHeight = 265;
  static const double _indicatorHeight = 19;

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselController();
    _carouselController.addListener(_handleCarouselScroll);
  }

  void _handleCarouselScroll() {
    if (!_carouselController.hasClients || widget.properties.isEmpty) return;

    final ScrollPosition position = _carouselController.position;
    if (!position.hasViewportDimension || position.viewportDimension == 0) {
      return;
    }

    final double itemScrollExtent =
        position.viewportDimension /
        _carouselWeights.reduce((value, element) => value + element);
    if (itemScrollExtent == 0) return;

    final int nextPage = math.max(
      0,
      math.min(
        widget.properties.length - 1,
        (_carouselController.offset / itemScrollExtent).round(),
      ),
    );

    if (nextPage == _currentPage) return;
    setState(() {
      _currentPage = nextPage;
    });
  }

  @override
  void didUpdateWidget(covariant _RecommendedPropertiesCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.properties.isEmpty) {
      _currentPage = 0;
      return;
    }

    if (_currentPage >= widget.properties.length) {
      _currentPage = widget.properties.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_carouselController.hasClients) return;
        unawaited(_carouselController.animateToItem(_currentPage));
      });
    }
  }

  @override
  void dispose() {
    _carouselController.removeListener(_handleCarouselScroll);
    _carouselController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.properties.isEmpty) return const SizedBox.shrink();

    final ThemeData theme = Theme.of(context);

    return SizedBox(
      height:
          _activeCardHeight +
          (widget.properties.length > 1 ? _indicatorHeight : 0),
      child: Column(
        children: [
          Expanded(
            child: CarouselView.weighted(
              controller: _carouselController,
              itemSnapping: true,
              flexWeights: _carouselWeights,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              backgroundColor: Colors.transparent,
              elevation: 0,
              itemClipBehavior: Clip.none,
              enableSplash: false,
              children: List<Widget>.generate(widget.properties.length, (
                index,
              ) {
                final Property property = widget.properties[index];
                final bool isActive = index == _currentPage;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      height: _activeCardHeight,
                      child: _RecommendedPropertyCard(
                        property: property,
                        isSaved: widget.savedProperties.contains(property),
                        isActive: isActive,
                        onToggleSave: () => widget.onToggleSave(property),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          if (widget.properties.length > 1) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.properties.length, (index) {
                final bool isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: isActive ? 18 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendedPropertyCard extends StatelessWidget {
  final Property property;
  final bool isSaved;
  final bool isActive;
  final VoidCallback onToggleSave;

  const _RecommendedPropertyCard({
    required this.property,
    required this.isSaved,
    required this.isActive,
    required this.onToggleSave,
  });

  Future<void> _openDetails(BuildContext context) async {
    await _precachePropertyImage(context, property, height: 300);
    if (!context.mounted) return;

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

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => unawaited(_openDetails(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _buildPropertyImage(
                  context: context,
                  property: property,
                  height: isActive ? 172 : 140,
                  useThumbnail: true,
                  fallbackChild: const Center(
                    child: Icon(
                      Icons.landscape_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: onToggleSave,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSaved
                            ? Icons.favorite
                            : Icons.favorite_border_rounded,
                        size: 18,
                        color: isSaved ? Colors.red : theme.iconTheme.color,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    property.price,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyTile extends StatelessWidget {
  final Property property;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const _PropertyTile({
    required this.property,
    required this.isSaved,
    required this.onToggleSave,
  });

  Future<void> _openDetails(BuildContext context) async {
    await _precachePropertyImage(context, property, height: 300);
    if (!context.mounted) return;

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

    Widget metaChip(IconData icon, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 112),
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

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => unawaited(_openDetails(context)),
        child: SizedBox(
          height: 118,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double thumbnailWidth = constraints.maxWidth / 3;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: thumbnailWidth,
                        height: 118,
                        child: _buildPropertyImage(
                          context: context,
                          property: property,
                          height: 118,
                          useThumbnail: true,
                          fallbackChild: const Center(
                            child: Icon(
                              Icons.landscape_rounded,
                              color: Colors.white,
                              size: 34,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  property.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: isSaved
                                    ? 'Remove from saved'
                                    : 'Save lot',
                                onPressed: onToggleSave,
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      theme.colorScheme.surfaceContainerHighest,
                                  foregroundColor: isSaved
                                      ? Colors.red
                                      : theme.iconTheme.color,
                                  fixedSize: const Size(36, 36),
                                  minimumSize: const Size(36, 36),
                                  padding: EdgeInsets.zero,
                                ),
                                icon: Icon(
                                  isSaved
                                      ? Icons.favorite
                                      : Icons.favorite_border_rounded,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  property.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  property.price,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              metaChip(
                                Icons.square_foot_outlined,
                                property.size,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class PropertyCard extends StatelessWidget {
  final Property property;
  final bool isSaved;
  final VoidCallback onToggleSave;
  final bool compact;

  const PropertyCard({
    super.key,
    required this.property,
    required this.isSaved,
    required this.onToggleSave,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final double imageHeight = compact ? 155 : 210;
    final EdgeInsets contentPadding = compact
        ? const EdgeInsets.fromLTRB(14, 12, 14, 14)
        : const EdgeInsets.fromLTRB(16, 16, 16, 18);
    final TextStyle? titleStyle =
        (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)
            ?.copyWith(fontWeight: FontWeight.w700);
    final double priceFontSize = compact ? 18 : 20;
    final double buttonVerticalPadding = compact ? 13 : 16;

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: isDark
            ? null
            : Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0x12000000)
                : theme.colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(22),
                ),
                child: _buildPropertyImage(
                  context: context,
                  property: property,
                  height: imageHeight,
                  useThumbnail: true,
                  fallbackChild: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.landscape_rounded,
                          size: 64,
                          color: Colors.white,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Lot Preview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: compact ? 12 : 14,
                left: compact ? 12 : 14,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 10 : 12,
                    vertical: compact ? 6 : 7,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    property.tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: compact ? 12 : 14,
                right: compact ? 12 : 14,
                child: GestureDetector(
                  onTap: onToggleSave,
                  child: Container(
                    width: compact ? 38 : 42,
                    height: compact ? 38 : 42,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isSaved ? Icons.favorite : Icons.favorite_border_rounded,
                      color: isSaved
                          ? Colors.red
                          : Theme.of(context).iconTheme.color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: contentPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.title,
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                  style: titleStyle,
                ),
                SizedBox(height: compact ? 6 : 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        property.location,
                        maxLines: compact ? 1 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 10 : 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            property.titleStatus,
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 14),
                Row(
                  children: [
                    Text(
                      property.price,
                      style: TextStyle(
                        fontSize: priceFontSize,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 10 : 12,
                        vertical: compact ? 7 : 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E3A23)
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        property.size,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? const Color(0xFF2E7D32)
                              : theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 12 : 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      unawaited(
                        _precachePropertyImage(context, property, height: 300),
                      );
                      if (!context.mounted) return;
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
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: buttonVerticalPadding,
                      ),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('View Details'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PropertyDetailsPage extends StatefulWidget {
  final Property property;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const PropertyDetailsPage({
    super.key,
    required this.property,
    required this.isSaved,
    required this.onToggleSave,
  });

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  late bool _isSaved;

  @override
  void initState() {
    super.initState();
    _isSaved = widget.isSaved;
  }

  void _handleToggleSave() {
    widget.onToggleSave();
    setState(() {
      _isSaved = !_isSaved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lot Details'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPropertyImage(
              context: context,
              property: widget.property,
              height: 300,
              fallbackChild: const Center(
                child: Icon(
                  Icons.landscape_rounded,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          widget.property.tag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _handleToggleSave,
                        icon: Icon(
                          _isSaved
                              ? Icons.favorite
                              : Icons.favorite_border_rounded,
                          size: 28,
                          color: _isSaved
                              ? Colors.red
                              : Theme.of(context).iconTheme.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.pin_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.property.referenceCode,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.property.title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.property.location,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 18,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.property.titleStatus,
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Price',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.property.price,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Lot Size',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.property.size,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.property.description.trim().isEmpty
                        ? 'No description available for this lot yet.'
                        : widget.property.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ContactAgentPage(property: widget.property),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Contact Agent',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class ContactAgentPage extends StatefulWidget {
  final Property property;

  const ContactAgentPage({super.key, required this.property});

  @override
  State<ContactAgentPage> createState() => _ContactAgentPageState();
}

class _ContactAgentPageState extends State<ContactAgentPage> {
  late TextEditingController _messageController;
  late TextEditingController _fullNameController;
  late TextEditingController _contactController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _contactController = TextEditingController();
    _messageController = TextEditingController(
      text:
          'Hi, I am interested in the ${widget.property.title} located at ${widget.property.location}. Please send me more details.',
    );
    unawaited(_loadProfile());
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final MessagingProfile? profile =
          await MessagingService.fetchCurrentProfile();
      if (!mounted) return;

      _fullNameController.text = profile?.fullName?.trim().isNotEmpty == true
          ? profile!.fullName!.trim()
          : ((user.userMetadata?['full_name'] ??
                        user.userMetadata?['name'] ??
                        '')
                    as String)
                .trim();

      final String preferredContact = (profile?.phone ?? '').trim().isNotEmpty
          ? profile!.phone!.trim()
          : ((profile?.email ?? user.email ?? user.phone ?? '')).trim();
      _contactController.text = preferredContact;
    } catch (_) {}
  }

  Future<void> _sendInquiry() async {
    final String fullName = _fullNameController.text.trim();
    final String contactValue = _contactController.text.trim();
    final String message = _messageController.text.trim();

    if (fullName.isEmpty || contactValue.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete your name, contact, and message.'),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await MessagingService.startConversationForProperty(
        property: widget.property,
        body: message,
        fullName: fullName,
        contactValue: contactValue,
      );

      if (!mounted) return;
      final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(content: Text('Message sent to agent successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
      setState(() {
        _isSending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact Agent'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Icon(Icons.person, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Juan Dela Cruz',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Senior Real Estate Agent',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Your Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              context,
              'Full Name',
              Icons.person_outline,
              _fullNameController,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              context,
              'Email or Phone Number',
              Icons.contact_mail_outlined,
              _contactController,
            ),
            const SizedBox(height: 24),
            Text(
              'Message',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Enter your message',
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendInquiry,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Send Message',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context,
    String hint,
    IconData icon,
    TextEditingController controller,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class PinCodePage extends StatefulWidget {
  const PinCodePage({super.key});

  @override
  State<PinCodePage> createState() => _PinCodePageState();
}

class _PinCodePageState extends State<PinCodePage> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final currentPin = appPinCodeNotifier.value;
    if (currentPin != null) {
      _pinController.text = currentPin;
      _confirmPinController.text = currentPin;
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _savePinCode() {
    final pin = _pinController.text.trim();
    final confirmPin = _confirmPinController.text.trim();

    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() {
        _errorText = 'PIN must be exactly 4 digits.';
      });
      return;
    }

    if (pin != confirmPin) {
      setState(() {
        _errorText = 'PIN entries do not match.';
      });
      return;
    }

    appPinCodeNotifier.value = pin;
    setState(() {
      _errorText = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN code saved.')));
    Navigator.pop(context);
  }

  void _clearPinCode() {
    appPinCodeNotifier.value = null;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('PIN code removed.')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN Code'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: _pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: InputDecoration(
                  hintText: 'Enter 4-digit PIN',
                  prefixIcon: const Icon(Icons.pin_outlined),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: InputDecoration(
                  hintText: 'Confirm PIN',
                  prefixIcon: const Icon(Icons.verified_user_outlined),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 12),
                Text(_errorText!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePinCode,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save PIN'),
                ),
              ),
              if (appPinCodeNotifier.value != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _clearPinCode,
                    child: const Text('Remove PIN'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subtitle;

  const EmptyState({
    super.key,
    this.icon = Icons.search_off,
    this.message = 'No lots matched your filters.',
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isLightTheme = theme.brightness == Brightness.light;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isLightTheme
            ? Border.all(color: theme.colorScheme.outlineVariant)
            : null,
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
