import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../app/config/app_config.dart';
import '../../../location/data/datasources/negros_places_datasource.dart';
import '../../../messaging/presentation/screens/messages_tab.dart'
    as messaging_screens;
import '../../../profile/data/services/avatar_picker_service.dart';
import '../../../profile/data/services/buyer_profile_service.dart';
import '../../../profile/data/services/profile_avatar_service.dart';
import '../../../profile/presentation/helpers/profile_avatar_state.dart';
import '../../../profile/presentation/screens/profile_tab.dart'
    as profile_screens;
import '../../../profile/presentation/widgets/avatar_options_sheet.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import '../../../properties/data/services/saved_property_storage_service.dart';
import '../../../properties/presentation/screens/saved_tab.dart';
import '../../../properties/presentation/widgets/property_image.dart';
import '../../../properties/presentation/widgets/saved_properties_upgrade_sheet.dart';
import '../../../subscription/data/services/subscription_service.dart';
import '../../../subscription/presentation/navigation/subscription_navigation.dart';
import '../helpers/home_filter_helpers.dart';
import 'home_tab.dart';

typedef MapTabBuilder =
    Widget Function(
      BuildContext context,
      Set<Property> savedProperties,
      ValueChanged<Property> onToggleSave,
    );

class HomePageView extends StatefulWidget {
  final MapTabBuilder mapTabBuilder;
  final Future<void> Function(BuildContext context) onLogout;

  const HomePageView({
    super.key,
    required this.mapTabBuilder,
    required this.onLogout,
  });

  @override
  State<HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends State<HomePageView> {
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

  void _applyProfileAvatarState(ProfileAvatarState avatarState) {
    _profileImageBytes = avatarState.imageBytes;
    _profileAvatarHidden = avatarState.avatarHidden;
    _hasRemoteProfileAvatar = avatarState.hasRemoteAvatar;
  }

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
        _applyProfileAvatarState(ProfileAvatarState.visible(imageBytes));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar saved to your profile.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save avatar: $error')));
    }
  }

  Future<void> _pickAvatarFromCamera() async {
    final Uint8List? imageBytes = await AvatarPickerService.pickCameraAvatar();
    if (imageBytes == null) return;

    setState(() {
      _applyProfileAvatarState(ProfileAvatarState.visible(imageBytes));
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
          _applyProfileAvatarState(ProfileAvatarState.removed);
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
    unawaited(
      SavedPropertyStorageService.saveSavedPropertyIds(_savedPropertyIds),
    );
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
      widget.mapTabBuilder(context, _savedProperties, _toggleSavedProperty),
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
        onLogout: widget.onLogout,
        onRemoteAvatarAvailableChanged: (hasRemoteAvatar) {
          if (_hasRemoteProfileAvatar == hasRemoteAvatar) return;
          setState(() {
            _hasRemoteProfileAvatar = hasRemoteAvatar;
          });
        },
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
