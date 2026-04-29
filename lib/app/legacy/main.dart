import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide ImageSource, Size;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_section_header.dart';
import '../../features/auth/presentation/widgets/google_logo_icon.dart';
import '../../features/auth/presentation/screens/change_password_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_page.dart';
import '../../features/auth/presentation/screens/sign_up_page.dart';
import '../../features/location/data/datasources/negros_places_datasource.dart';
import '../../features/agent/presentation/screens/agent_dashboard_screen.dart';
import '../../features/home/presentation/widgets/active_filter_chip.dart';
import '../../features/home/presentation/widgets/search_section.dart';
import '../../features/home/presentation/widgets/sticky_search_header_delegate.dart';
import '../../features/home/presentation/widgets/top_header.dart';
import '../../features/messaging/data/services/messaging_service.dart';
import '../../features/messaging/presentation/widgets/chat_loading_placeholder.dart';
import '../../features/messaging/presentation/widgets/inbox_conversation_helpers.dart';
import '../../features/messaging/presentation/widgets/message_palettes.dart';
import '../../features/profile/data/services/buyer_profile_service.dart';
import '../../features/profile/data/models/profile_model.dart';
import '../../features/profile/presentation/screens/account_page.dart';
import '../../features/profile/presentation/screens/pin_code_screen.dart';
import '../../features/profile/presentation/widgets/profile_formatters.dart';
import '../../features/properties/data/datasources/shared_properties.dart';
import '../../features/properties/presentation/screens/property_details_inline_screen.dart';
import '../../features/properties/presentation/widgets/property_tile.dart';
import '../../features/properties/presentation/widgets/property_image.dart';
import '../../features/properties/presentation/widgets/recommended_properties_carousel.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/subscription/data/services/subscription_service.dart';
import '../../core/constants/storage_constants.dart';
import '../config/app_config.dart';
import '../config/auth_config.dart';
import '../config/supabase_config.dart';
import '../router/instant_route.dart';
import '../state/app_display_preferences.dart' as app_display_preferences;
import '../state/app_display_preferences.dart'
    show appFontScaleNotifier, appThemeNotifier;
import '../state/inline_property_details_controller.dart';
import '../state/app_pin_code.dart';
import '../state/inline_property_details_state.dart';
import '../theme/legacy_app_theme.dart';

part '../../features/map/presentation/screens/legacy_map_tab.dart';

Future<void> main() async {
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
      url: SupabaseConfig.effectiveUrl,
      anonKey: SupabaseConfig.effectiveAnonKey,
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
  final SharedPreferences preferences = await SharedPreferences.getInstance();
  final bool followSystemTheme =
      preferences.getBool(StorageConstants.followSystemThemeEnabled) ?? true;
  final String? preferredThemeMode = preferences.getString(
    StorageConstants.preferredThemeMode,
  );
  appThemeNotifier.value = followSystemTheme
      ? ThemeMode.system
      : (preferredThemeMode == 'dark' ? ThemeMode.dark : ThemeMode.light);

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
              themeAnimationDuration: const Duration(milliseconds: 220),
              themeAnimationCurve: Curves.easeOutCubic,
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(fontScale)),
                  child: child!,
                );
              },
              theme: buildLegacyLightTheme(),
              darkTheme: buildLegacyDarkTheme(),
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
  bool _profileAvatarHidden = false;
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
    unawaited(_warmCurrentUserAvatar());
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

  Future<void> _warmCurrentUserAvatar() async {
    try {
      final MessagingProfile? profile =
          await MessagingService.fetchCurrentProfile();
      final String avatarUrl = profileTextValue(
        profile?.avatarUrl ??
            Supabase
                .instance
                .client
                .auth
                .currentUser
                ?.userMetadata?['avatar_url'],
      );
      if (!mounted || _profileAvatarHidden || avatarUrl.isEmpty) return;

      await precacheImage(CachedNetworkImageProvider(avatarUrl), context);
    } catch (_) {}
  }

  void _warmInitialPropertyCardImages(List<Property> properties) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      for (final Property property in properties.take(
        AppConfig.initialPropertyImagePrefetchCount,
      )) {
        if (_warmedPropertyImageIds.add(property.id)) {
          warmPropertyImage(context, property, useThumbnail: true);
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
        preferences.getStringList(StorageConstants.savedPropertyIds)?.toSet() ??
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
      StorageConstants.savedPropertyIds,
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

  Uint8List _optimizeAvatarImage(Uint8List bytes) {
    final img.Image? decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) return bytes;

    final img.Image orientedImage = img.bakeOrientation(decodedImage);
    final int cropSize = math.min(orientedImage.width, orientedImage.height);
    final int cropX = ((orientedImage.width - cropSize) / 2).floor();
    final int cropY = ((orientedImage.height - cropSize) / 2).floor();
    final img.Image squareImage = img.copyCrop(
      orientedImage,
      x: cropX,
      y: cropY,
      width: cropSize,
      height: cropSize,
    );
    final int avatarSize = squareImage.width > 512 ? 512 : squareImage.width;
    final img.Image avatarImage = img.copyResize(
      squareImage,
      width: avatarSize,
      height: avatarSize,
      interpolation: img.Interpolation.average,
    );

    return Uint8List.fromList(img.encodeJpg(avatarImage, quality: 70));
  }

  Future<void> _saveAvatarForCurrentUser(Uint8List imageBytes) async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in again before uploading your avatar.');
    }

    final String avatarPath =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await Supabase.instance.client.storage
        .from(SupabaseConfig.profileAvatarsBucket)
        .uploadBinary(
          avatarPath,
          imageBytes,
          fileOptions: const FileOptions(
            cacheControl: '604800',
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final String avatarUrl = Supabase.instance.client.storage
        .from(SupabaseConfig.profileAvatarsBucket)
        .getPublicUrl(avatarPath);

    await Supabase.instance.client.from('profiles').upsert({
      'id': user.id,
      'avatar_url': avatarUrl,
    }, onConflict: 'id');
  }

  Future<void> _removeAvatarForCurrentUser() async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client
        .from('profiles')
        .update({'avatar_url': null})
        .eq('id', user.id);
  }

  Future<void> _pickAvatarFromGallery() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (pickedFile != null) {
      final Uint8List imageBytes = _optimizeAvatarImage(
        await pickedFile.readAsBytes(),
      );
      try {
        await _saveAvatarForCurrentUser(imageBytes);
        if (!mounted) return;
        setState(() {
          _profileImageBytes = imageBytes;
          _profileAvatarHidden = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar saved to your profile.')),
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save avatar: $error')),
        );
      }
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
                      _profileAvatarHidden = true;
                    });
                    unawaited(_removeAvatarForCurrentUser());
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
      MapTab(
        savedProperties: _savedProperties,
        onToggleSave: _toggleSavedProperty,
      ),
      SavedTab(
        savedProperties: _savedProperties.toList(),
        onToggleSave: _toggleSavedProperty,
        subscription: appSubscriptionNotifier.value,
        onOpenSubscription: _openSubscriptionPage,
      ),
      const MessagesTab(),
      ProfileTab(
        profileImageBytes: _profileImageBytes,
        profileAvatarHidden: _profileAvatarHidden,
        onAvatarTap: _showAvatarOptions,
      ),
    ];

    return ValueListenableBuilder<InlinePropertyDetailsState?>(
      valueListenable: appInlinePropertyDetailsNotifier,
      builder: (context, inlineDetails, child) {
        return Scaffold(
          body: inlineDetails == null
              ? pages[_currentIndex]
              : PropertyDetailsInlineView(
                  property: inlineDetails.property,
                  isSaved: inlineDetails.isSaved,
                  onToggleSave: inlineDetails.onToggleSave,
                  onBack: hideInlinePropertyDetails,
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              hideInlinePropertyDetails();
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
      },
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
        ActiveFilterChip(
          label: selectedLocation!,
          onDeleted: () => onLocationChanged(null),
        ),
      if (selectedLotSize != null)
        ActiveFilterChip(
          label: selectedLotSize!,
          onDeleted: () => onLotSizeChanged(null),
        ),
      if (selectedBudget != null)
        ActiveFilterChip(
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
              delegate: StickySearchHeaderDelegate(
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
                  child: RecommendedPropertiesCarousel(
                    properties: recommendedProperties,
                    savedProperties: savedProperties,
                    onToggleSave: onToggleSave,
                    onOpenDetails: (property) {
                      showInlinePropertyDetails(
                        context: context,
                        property: property,
                        isSaved: savedProperties.contains(property),
                        onToggleSave: () => onToggleSave(property),
                      );
                    },
                    onPrecacheDetails: (context, property) {
                      unawaited(
                        precachePropertyImage(context, property, height: 300),
                      );
                    },
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
                      padding: const EdgeInsets.only(bottom: 10),
                      child: PropertyTile(
                        property: property,
                        isSaved: savedProperties.contains(property),
                        onToggleSave: () => onToggleSave(property),
                        onOpenDetails: () {
                          showInlinePropertyDetails(
                            context: context,
                            property: property,
                            isSaved: savedProperties.contains(property),
                            onToggleSave: () => onToggleSave(property),
                          );
                        },
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
                                child: buildPropertyImage(
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
                            onTap: () {
                              showInlinePropertyDetails(
                                context: context,
                                property: property,
                                isSaved: true,
                                onToggleSave: () => onToggleSave(property),
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

class _MessagesTabState extends State<MessagesTab> {
  bool _isLoading = true;
  String? _errorText;
  List<ConversationSummary> _conversations = const [];
  final Map<String, double> _dismissProgressByConversationId =
      <String, double>{};
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

  InboxCardPalette _paletteForConversation(
    BuildContext context,
    ConversationSummary conversation,
  ) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return InboxCardPalette(
      background: colorScheme.surface,
      border: colorScheme.outlineVariant,
      accent: colorScheme.primary,
      avatarBackground: colorScheme.surfaceContainerHighest,
      avatarForeground: colorScheme.onSurface,
    );
  }

  void _setConversationDismissProgress(
    String conversationId,
    double progress,
  ) {
    final double clampedProgress = progress.clamp(0.0, 1.0).toDouble();
    final double currentProgress =
        _dismissProgressByConversationId[conversationId] ?? 0;
    if (clampedProgress <= 0) {
      if (!_dismissProgressByConversationId.containsKey(conversationId)) return;
      setState(() {
        _dismissProgressByConversationId.remove(conversationId);
      });
      return;
    }

    if ((currentProgress - clampedProgress).abs() < 0.02) return;
    setState(() {
      _dismissProgressByConversationId[conversationId] = clampedProgress;
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
      instantRoute(
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
    final String displayTitle = buyerInboxConversationTitle(conversation);
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
    final String displayTitle = buyerInboxConversationTitle(conversation);
    final InboxCardPalette palette = _paletteForConversation(
      context,
      conversation,
    );
    final ImageProvider<Object>? propertyImageProvider =
        buyerInboxConversationImageProvider(context, conversation);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      onUpdate: (details) {
        _setConversationDismissProgress(conversation.id, details.progress);
      },
      confirmDismiss: (_) async {
        final bool shouldDelete = await _confirmDeleteConversation(
          conversation,
        );
        if (!shouldDelete && mounted) {
          _setConversationDismissProgress(conversation.id, 0);
        }
        return shouldDelete;
      },
      onDismissed: (_) {
        _dismissProgressByConversationId.remove(conversation.id);
        _deleteConversation(conversation);
      },
      background: const SizedBox.shrink(),
      secondaryBackground: _buildDeleteSwipeBackground(
        context,
        conversation.id,
      ),
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
            child: InkWell(
              onTap: () => _openConversation(conversation),
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
                                      messageInitial(displayTitle),
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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
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
                                    ),
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 1),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
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
                                            formatInboxTimestamp(
                                              conversation.lastMessageAt,
                                            ),
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
                                Text(
                                  'Chat Agent',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
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
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteSwipeBackground(
    BuildContext context,
    String conversationId,
  ) {
    const Color lightOrange = Color(0xFFFFE0B2);
    const Color warmOrange = Color(0xFFFFB74D);
    const Color iconForeground = Color(0xFF7A3E00);
    final double progress =
        (_dismissProgressByConversationId[conversationId] ?? 0)
            .clamp(0.0, 1.0)
            .toDouble();
    final double opacity = Curves.easeOutCubic.transform(progress);
    final double scaleProgress = Curves.easeOutBack
        .transform(progress)
        .clamp(0.0, 1.12)
        .toDouble();
    final double iconScale = 0.7 + (0.3 * scaleProgress);
    final double iconRotation = -0.28 + (0.28 * opacity);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              warmOrange.withValues(alpha: 0.7),
              lightOrange.withValues(alpha: 0.36),
              lightOrange.withValues(alpha: 0),
            ],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 18),
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(16 * (1 - progress), 0),
              child: Transform.scale(
                scale: iconScale,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Transform.rotate(
                    angle: iconRotation,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: iconForeground,
                      size: 32,
                    ),
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
  final bool profileAvatarHidden;
  final VoidCallback onAvatarTap;

  const ProfileTab({
    super.key,
    required this.profileImageBytes,
    required this.profileAvatarHidden,
    required this.onAvatarTap,
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  late final Future<BuyerProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileAndPrecacheAvatar();
  }

  Future<BuyerProfileData> _loadProfileAndPrecacheAvatar() async {
    final BuyerProfileData profile = await loadCurrentBuyerProfileData();
    final String avatarUrl = (profile.avatarUrl ?? '').trim();
    if (mounted &&
        !widget.profileAvatarHidden &&
        widget.profileImageBytes == null &&
        avatarUrl.isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(avatarUrl), context);
      } catch (_) {}
    }
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ValueListenableBuilder<UserSubscription>(
        valueListenable: appSubscriptionNotifier,
        builder: (context, currentSubscription, child) {
          return FutureBuilder<BuyerProfileData>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final BuyerProfileData profile = resolveBuyerProfileData(
                snapshot.data,
                currentSubscription,
              );
              final String avatarUrl = (profile.avatarUrl ?? '').trim();
              final ImageProvider<Object>? avatarImageProvider =
                  widget.profileImageBytes != null
                  ? MemoryImage(widget.profileImageBytes!)
                  : !widget.profileAvatarHidden && avatarUrl.isNotEmpty
                  ? CachedNetworkImageProvider(avatarUrl)
                  : null;

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
                            backgroundImage: avatarImageProvider,
                            child: avatarImageProvider == null
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
                              ? '${profile.planName} until ${formatSubscriptionDate(profile.expiresAt)}'
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

  ChatColorPalette _chatPalette(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    return ChatColorPalette(
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
    final ChatColorPalette palette = _chatPalette(context);

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
                  return const ChatLoadingPlaceholder();
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

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  late bool _followSystemTheme;
  late ThemeMode _preferredThemeMode;
  bool _notifyNewProperties = true;
  bool _notifyPriceDrops = true;
  bool _notifyMessages = true;
  double _currentFontSizeScale = 1.0; // Default font size scale

  @override
  void initState() {
    super.initState();
    final Brightness systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _followSystemTheme = appThemeNotifier.value == ThemeMode.system;
    final bool shouldUseDarkPreference =
        appThemeNotifier.value == ThemeMode.dark ||
        (appThemeNotifier.value == ThemeMode.system &&
            systemBrightness == Brightness.dark);
    _preferredThemeMode = shouldUseDarkPreference
        ? ThemeMode.dark
        : ThemeMode.light;
    _currentFontSizeScale = appFontScaleNotifier.value;
    unawaited(_loadPreferredThemeMode());
  }

  Future<void> _loadPreferredThemeMode() async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final String? preferredThemeMode = preferences.getString(
      StorageConstants.preferredThemeMode,
    );
    if (!mounted || preferredThemeMode == null) return;

    setState(() {
      _preferredThemeMode = preferredThemeMode == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;
      if (!_followSystemTheme) {
        appThemeNotifier.value = _preferredThemeMode;
      }
    });
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

  Widget _buildAppearanceSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    ValueChanged<bool>? onChanged,
    bool isChild = false,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bool isEnabled = onChanged != null;
    final Color activeSwitchColor = isDarkMode
        ? const Color(0xFF7DD3FC)
        : Theme.of(context).colorScheme.primary;

    return ListTile(
      enabled: isEnabled,
      dense: isChild,
      title: Text(
        title,
        style: isChild ? theme.textTheme.bodyMedium : null,
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: isChild ? theme.textTheme.bodySmall : null,
            ),
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: isEnabled ? () => onChanged(!value) : null,
      trailing: Transform.scale(
        scale: 0.76,
        alignment: Alignment.centerRight,
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: activeSwitchColor,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required List<Widget> children,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.30),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode
                      ? Colors.black.withValues(alpha: 0.14)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _settingsDivider() {
    return const Divider(height: 1, indent: 16, endIndent: 16);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;
    final Color activeSwitchColor = isDarkMode
        ? const Color(0xFF7DD3FC)
        : theme.colorScheme.primary;
    final user = Supabase.instance.client.auth.currentUser;
    final String accountLabel = user?.email ?? 'Logged in account';

    return Scaffold(
      backgroundColor: isDarkMode
          ? theme.scaffoldBackgroundColor
          : const Color(0xFFF7F8FA),
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: Theme(
        data: theme.copyWith(
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AccountPage(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: theme.dividerColor.withValues(alpha: 0.30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode
                            ? Colors.black.withValues(alpha: 0.14)
                            : Colors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        foregroundColor: theme.colorScheme.primary,
                        child: Text(
                              messageInitial(accountLabel),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Account Settings',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              accountLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildSectionCard(
              title: 'Notifications',
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
                if (_notificationsEnabled) ...[
                  _settingsDivider(),
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
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
                        _settingsDivider(),
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
                        _settingsDivider(),
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
                ],
              ],
            ),
            _buildSectionCard(
              title: 'Appearance',
              children: [
                ListTile(
                  title: const Text('Font Size'),
                  subtitle: Text(
                    'Adjust text size for better readability (${_currentFontSizeScale.toStringAsFixed(1)}x)',
                  ),
                  leading: const Icon(Icons.format_size),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                    left: 16,
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
              ],
            ),
            _buildSectionCard(
              title: 'Dark Mode',
              children: [
                _buildAppearanceSwitchTile(
                  title: 'Follow System Theme',
                  subtitle: 'Match your phone display mode',
                  value: _followSystemTheme,
                  isChild: true,
                  onChanged: (value) {
                    setState(() {
                      _followSystemTheme = value;
                      if (value) {
                        _preferredThemeMode = ThemeMode.light;
                        appThemeNotifier.value = ThemeMode.system;
                      } else {
                        appThemeNotifier.value = _preferredThemeMode;
                      }
                    });
                    unawaited(
                      app_display_preferences.AppDisplayPreferences
                          .persistFollowSystemThemePreference(value),
                    );
                    if (value) {
                      unawaited(
                        app_display_preferences.AppDisplayPreferences
                            .persistPreferredThemeMode(ThemeMode.light),
                      );
                    } else {
                      unawaited(
                        app_display_preferences.AppDisplayPreferences
                            .persistPreferredThemeMode(_preferredThemeMode),
                      );
                    }
                  },
                ),
                _settingsDivider(),
                _buildAppearanceSwitchTile(
                  title: 'Use Dark Theme',
                  subtitle: 'Use your preferred app theme',
                  value:
                      !_followSystemTheme &&
                      _preferredThemeMode == ThemeMode.dark,
                  isChild: true,
                  onChanged: _followSystemTheme
                      ? null
                      : (value) {
                          final ThemeMode selectedThemeMode = value
                              ? ThemeMode.dark
                              : ThemeMode.light;
                          setState(() {
                            _preferredThemeMode = selectedThemeMode;
                            appThemeNotifier.value = selectedThemeMode;
                          });
                          unawaited(
                            app_display_preferences.AppDisplayPreferences
                                .persistPreferredThemeMode(selectedThemeMode),
                          );
                        },
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Security',
              children: [
                ListTile(
                  title: const Text('Password'),
                  subtitle: const Text('Update your account password'),
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
                _settingsDivider(),
                ValueListenableBuilder<String?>(
                  valueListenable: appPinCodeNotifier,
                  builder: (context, pinCode, child) {
                    return ListTile(
                      title: const Text('PIN Code'),
                      subtitle: Text(
                        pinCode == null
                            ? 'Protect access with a 4-digit PIN'
                            : 'PIN is configured',
                      ),
                      leading: const Icon(Icons.pin_outlined),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PinCodePage(),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            _buildSectionCard(
              title: 'Support',
              children: [
                ListTile(
                  title: const Text('Help & Support'),
                  leading: const Icon(Icons.help_outline),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                _settingsDivider(),
                ListTile(
                  title: const Text('About'),
                  leading: const Icon(Icons.info_outline),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
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
        builder: (context) => ChangePasswordPage(
          isPasswordRecovery: true,
          recoveryLoginBuilder: (context) => const LoginPage(),
        ),
      ),
    );

    if (mounted) {
      _isOpeningPasswordRecovery = false;
    }
  }

  Future<void> _routeByRole(User user) async {
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
          .take(AppConfig.initialPropertyImagePrefetchCount)
          .toList(growable: false);
      await Future.wait(
        initialProperties.map(
          (property) =>
              precachePropertyImage(context, property, useThumbnail: true),
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
        redirectTo: kIsWeb ? null : AuthConfig.redirectUrl,
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
                  const KsnHeaderLogo(size: 88),
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
                                  : const GoogleLogoIcon(),
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


