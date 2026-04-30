import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide ImageSource, Size;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/auth/data/services/auth_session_service.dart';
import '../../features/auth/domain/helpers/auth_user_role.dart';
import '../../features/auth/presentation/helpers/auth_error_messages.dart';
import '../../features/auth/presentation/helpers/dev_auth_shortcuts.dart';
import '../../features/auth/presentation/navigation/auth_navigation.dart';
import '../../features/auth/presentation/widgets/google_logo_icon.dart';
import '../../features/auth/presentation/screens/forgot_password_page.dart';
import '../../features/auth/presentation/screens/sign_up_page.dart';
import '../../features/location/data/datasources/negros_places_datasource.dart';
import '../../features/agent/presentation/screens/agent_dashboard_screen.dart';
import '../../features/home/presentation/widgets/top_header.dart';
import '../../features/home/presentation/helpers/home_filter_helpers.dart';
import '../../features/messaging/presentation/screens/messages_tab.dart'
    as messaging_screens;
import '../../features/profile/data/services/avatar_picker_service.dart';
import '../../features/profile/data/services/profile_avatar_service.dart';
import '../../features/profile/data/services/buyer_profile_service.dart';
import '../../features/profile/presentation/screens/profile_tab.dart'
    as profile_screens;
import '../../features/profile/presentation/widgets/avatar_options_sheet.dart';
import '../../features/properties/data/datasources/shared_properties.dart';
import '../../features/properties/data/services/saved_property_storage_service.dart';
import '../../features/properties/presentation/screens/property_details_inline_screen.dart';
import '../../features/properties/presentation/widgets/property_image.dart';
import '../../features/properties/presentation/widgets/saved_properties_upgrade_sheet.dart';
import '../../features/home/presentation/screens/home_tab.dart';
import '../../features/properties/presentation/screens/saved_tab.dart';
import '../../features/subscription/presentation/navigation/subscription_navigation.dart';
import '../../features/subscription/data/services/subscription_service.dart';
import '../real_estate_app.dart';
import '../bootstrap/legacy_app_bootstrap.dart';
import '../config/app_config.dart';
import '../config/mapbox_config.dart';
import '../router/instant_route.dart';
import '../state/inline_property_details_controller.dart';
import '../state/inline_property_details_state.dart';

part '../../features/map/presentation/screens/legacy_map_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeLegacyAppBootstrap();
  runApp(const RealEstateApp(home: LoginPage()));
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
  bool _hasRemoteProfileAvatar = false;

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
          SavedPropertyStorageService.resolveSavedProperties(
            availableProperties: _availableProperties,
            savedPropertyIds: _savedPropertyIds,
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
    if (_profileAvatarHidden) return;
    await ProfileAvatarService.warmCurrentUserAvatar(context);
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
    final SavedPropertiesSnapshot savedPropertiesSnapshot =
        await SavedPropertyStorageService.loadSavedProperties(
          availableProperties: _availableProperties,
        );

    if (!mounted || savedPropertiesSnapshot.savedPropertyIds.isEmpty) return;

    setState(() {
      _savedPropertyIds
        ..clear()
        ..addAll(savedPropertiesSnapshot.savedPropertyIds);
      _savedProperties
        ..clear()
        ..addAll(savedPropertiesSnapshot.savedProperties);
    });
  }

  Future<void> _persistSavedProperties() async {
    await SavedPropertyStorageService.saveSavedPropertyIds(_savedPropertyIds);
  }

  Future<void> _openSubscriptionPage() async {
    await openSubscriptionPage(context);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _showSavedPropertiesUpgradePrompt() async {
    await showSavedPropertiesUpgradeSheet(
      context: context,
      onViewPlans: _openSubscriptionPage,
    );
  }

  Future<void> _pickAvatarFromGallery() async {
    final Uint8List? imageBytes = await AvatarPickerService.pickGalleryAvatar();
    if (imageBytes == null) return;

    try {
      await ProfileAvatarService.saveAvatarForCurrentUser(imageBytes);
      if (!mounted) return;
      setState(() {
        _profileImageBytes = imageBytes;
        _profileAvatarHidden = false;
        _hasRemoteProfileAvatar = true;
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

  Future<void> _pickAvatarFromCamera() async {
    final Uint8List? imageBytes = await AvatarPickerService.pickCameraAvatar();
    if (imageBytes == null) return;

    setState(() {
      _profileImageBytes = imageBytes;
      _profileAvatarHidden = false;
      _hasRemoteProfileAvatar = true;
    });
  }

  void _showAvatarOptions() {
    showAvatarOptionsSheet(
      context: context,
      canRemoveAvatar: _profileImageBytes != null || _hasRemoteProfileAvatar,
      onChooseFromGallery: _pickAvatarFromGallery,
      onTakePhoto: _pickAvatarFromCamera,
      onRemoveAvatar: () {
        setState(() {
          _profileImageBytes = null;
          _profileAvatarHidden = true;
          _hasRemoteProfileAvatar = false;
        });
        unawaited(ProfileAvatarService.removeAvatarForCurrentUser());
      },
    );
  }

  List<Property> get _filteredProperties {
    return filterHomeProperties(
      availableProperties: _availableProperties,
      negrosPlaces: _negrosPlaces,
      searchQuery: _searchQuery,
      selectedLocation: _selectedLocation,
      selectedLotSize: _selectedLotSize,
      selectedBudget: _selectedBudget,
    );
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
    final bool isAlreadySaved = _savedProperties.contains(property);
    final bool shouldShowUpgradePrompt =
        SavedPropertyStorageService.shouldShowUpgradePrompt(
          isAlreadySaved: isAlreadySaved,
          isPremium: appSubscriptionNotifier.value.isPremium,
          savedCount: _savedProperties.length,
          freeLimit: freeSavedPropertiesLimit,
        );

    if (shouldShowUpgradePrompt) {
      unawaited(_showSavedPropertiesUpgradePrompt());
      return;
    }

    setState(() {
      SavedPropertyStorageService.toggleSavedProperty(
        property: property,
        savedProperties: _savedProperties,
        savedPropertyIds: _savedPropertyIds,
      );
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
        locationItems: homeLocationFilterItems(_negrosPlaces),
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
        onLogout: _signOutAndReturnToLegacyLogin,
        onRemoteAvatarAvailableChanged: (hasRemoteAvatar) {
          if (_hasRemoteProfileAvatar == hasRemoteAvatar) return;
          setState(() {
            _hasRemoteProfileAvatar = hasRemoteAvatar;
          });
        },
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






Future<void> _signOutAndReturnToLegacyLogin(BuildContext context) {
  return signOutAndReturnToLogin(
    context,
    loginBuilder: (context) => const LoginPage(),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  String? _errorText;
  StreamSubscription<AuthState>? _authSubscription;
  bool _isRouting = false;
  bool _isOpeningPasswordRecovery = false;

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
    await openPasswordRecoveryPage(
      context,
      loginBuilder: (context) => const LoginPage(),
    );

    if (mounted) {
      _isOpeningPasswordRecovery = false;
    }
  }

  Future<void> _routeByRole(User user) async {
    await loadProperties();

    if (!mounted) return;
    if (isAdminAuthUser(user)) {
      await replaceWithAuthenticatedAdmin(
        context,
        adminBuilder: (context) =>
            AdminHomePage(onLogout: _signOutAndReturnToLegacyLogin),
      );
    } else {
      await precacheInitialPropertyImages(
        context: context,
        properties: appPropertiesNotifier.value,
        count: AppConfig.initialPropertyImagePrefetchCount,
      );
      if (!mounted) return;
      await replaceWithAuthenticatedHome(
        context,
        homeBuilder: (context) => const HomePage(),
      );
    }
  }

  Future<void> _signIn() async {
    final enteredEmail = _emailController.text.trim();
    final enteredPassword = _passwordController.text;
    final DevAuthShortcutResult devShortcut = devAuthShortcutForCredentials(
      email: enteredEmail,
      password: enteredPassword,
    );
    final String? disabledDevShortcutMessage = devShortcut.disabledMessage;

    if (disabledDevShortcutMessage != null) {
      setState(() {
        _errorText = disabledDevShortcutMessage;
      });
      return;
    }

    if (devShortcut.isUser) {
      setState(() {
        _isLoading = true;
        _errorText = null;
      });

      try {
        final User? user = await AuthSessionService.signInWithDevUserShortcut();
        await _routeToAuthenticatedUser(user);
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

    final email = devShortcut.emailFor(enteredEmail);
    final password = devShortcut.passwordFor(enteredPassword);

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
      final User? user = await AuthSessionService.signInWithPassword(
        email: email,
        password: password,
      );
      await _routeToAuthenticatedUser(user);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = passwordSignInErrorMessage(e.message);
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
      await AuthSessionService.signInWithGoogle();
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


