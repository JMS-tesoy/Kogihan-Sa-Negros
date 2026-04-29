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
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide ImageSource, Size;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/presentation/widgets/google_logo_icon.dart';
import '../../features/auth/presentation/screens/change_password_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_page.dart';
import '../../features/auth/presentation/screens/sign_up_page.dart';
import '../../features/location/data/datasources/negros_places_datasource.dart';
import '../../features/agent/presentation/screens/agent_dashboard_screen.dart';
import '../../features/home/presentation/widgets/top_header.dart';
import '../../features/home/presentation/helpers/home_filter_helpers.dart';
import '../../features/messaging/data/services/messaging_service.dart';
import '../../features/messaging/presentation/screens/messages_tab.dart'
    as messaging_screens;
import '../../features/profile/data/services/avatar_image_optimizer.dart';
import '../../features/profile/data/services/profile_avatar_service.dart';
import '../../features/profile/data/services/buyer_profile_service.dart';
import '../../features/profile/presentation/screens/profile_tab.dart'
    as profile_screens;
import '../../features/profile/presentation/widgets/profile_formatters.dart';
import '../../features/profile/presentation/widgets/avatar_options_sheet.dart';
import '../../features/properties/data/datasources/shared_properties.dart';
import '../../features/properties/data/services/saved_property_storage_service.dart';
import '../../features/properties/presentation/screens/property_details_inline_screen.dart';
import '../../features/properties/presentation/widgets/property_image.dart';
import '../../features/properties/presentation/widgets/saved_properties_upgrade_sheet.dart';
import '../../features/home/presentation/screens/home_tab.dart';
import '../../features/properties/presentation/screens/saved_tab.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/subscription/data/services/subscription_service.dart';
import '../../core/constants/storage_constants.dart';
import '../config/app_config.dart';
import '../config/auth_config.dart';
import '../config/supabase_config.dart';
import '../router/instant_route.dart';
import '../state/app_display_preferences.dart'
    show appFontScaleNotifier, appThemeNotifier;
import '../state/inline_property_details_controller.dart';
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
    _scheduleInitialPropertyCardImageWarmup(_availableProperties);
    unawaited(_restoreSavedProperties());
    unawaited(syncSubscriptionFromCurrentProfile());
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
    _scheduleInitialPropertyCardImageWarmup(_availableProperties);
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

  void _scheduleInitialPropertyCardImageWarmup(List<Property> properties) {
    scheduleInitialPropertyImageWarmup(
      context: context,
      properties: properties,
      warmedPropertyImageIds: _warmedPropertyImageIds,
      count: AppConfig.initialPropertyImagePrefetchCount,
    );
  }

  Future<void> _restoreSavedProperties() async {
    final Set<String> savedIds =
        await SavedPropertyStorageService.loadSavedPropertyIds();

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
    await SavedPropertyStorageService.saveSavedPropertyIds(_savedPropertyIds);
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
        return SavedPropertiesUpgradeSheet(
          onViewPlans: _openSubscriptionPage,
        );
      },
    );
  }

  Future<void> _pickAvatarFromGallery() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (pickedFile != null) {
      final Uint8List imageBytes = optimizeAvatarImage(
        await pickedFile.readAsBytes(),
      );
      try {
        await ProfileAvatarService.saveAvatarForCurrentUser(imageBytes);
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
        return AvatarOptionsSheet(
          canRemoveAvatar: _profileImageBytes != null,
          onChooseFromGallery: _pickAvatarFromGallery,
          onTakePhoto: _pickAvatarFromCamera,
          onRemoveAvatar: () {
            setState(() {
              _profileImageBytes = null;
              _profileAvatarHidden = true;
            });
            unawaited(ProfileAvatarService.removeAvatarForCurrentUser());
          },
        );
      },
    );
  }

  List<Property> get _filteredProperties {
    final String normalizedQuery = normalizeSearchText(_searchQuery);
    final String numericQuery = digitsOnly(_searchQuery);
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
              final List<double>? propertyCoordinates = parsePropertyCoordinates(
                property.location,
              );
              final double? placeLatitude = selectedPlace.latitude;
              final double? placeLongitude = selectedPlace.longitude;

              if (propertyCoordinates == null ||
                  placeLatitude == null ||
                  placeLongitude == null) {
                return false;
              }

              final double propertyDistanceInKm = distanceInKm(
                startLatitude: propertyCoordinates[0],
                startLongitude: propertyCoordinates[1],
                endLatitude: placeLatitude,
                endLongitude: placeLongitude,
              );

              if (propertyDistanceInKm > 25) return false;
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

          final String normalizedTitle = normalizeSearchText(property.title);
          final String normalizedLocation = normalizeSearchText(
            property.location,
          );
          final String normalizedPrice = normalizeSearchText(property.price);

          if (normalizedTitle.contains(normalizedQuery) ||
              normalizedLocation.contains(normalizedQuery) ||
              normalizedPrice.contains(normalizedQuery)) {
            return true;
          }

          if (numericQuery.isEmpty) return false;

          final String numericPrice = digitsOnly(property.price);
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
      const messaging_screens.MessagesTab(),
      profile_screens.ProfileTab(
        profileImageBytes: _profileImageBytes,
        profileAvatarHidden: _profileAvatarHidden,
        onAvatarTap: _showAvatarOptions,
        onLogout: _signOutAndReturnToLogin,
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


