import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../../home/presentation/helpers/home_filter_helpers.dart';
import '../../../home/presentation/widgets/search_section.dart';
import '../../../location/data/datasources/negros_places_datasource.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import '../../../properties/data/services/saved_property_storage_service.dart';
import '../../../properties/presentation/screens/property_details_screen.dart';
import '../../../properties/presentation/widgets/property_tile.dart';
import '../../../properties/presentation/widgets/saved_properties_upgrade_sheet.dart';
import '../../../subscription/data/services/subscription_service.dart';
import '../../../subscription/presentation/navigation/subscription_navigation.dart';

class PropertySearchResultsScreen extends StatefulWidget {
  const PropertySearchResultsScreen({
    super.key,
    required this.title,
    this.savedOnly = false,
  });

  final String title;
  final bool savedOnly;

  @override
  State<PropertySearchResultsScreen> createState() =>
      _PropertySearchResultsScreenState();
}

class _PropertySearchResultsScreenState
    extends State<PropertySearchResultsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _savedPropertyIds = <String>{};
  final Set<Property> _savedProperties = <Property>{};

  List<Property> _availableProperties = List<Property>.from(
    appPropertiesNotifier.value,
  );
  List<NegrosPlace> _negrosPlaces = List<NegrosPlace>.from(
    appNegrosPlacesNotifier.value,
  );
  String? _selectedLocation;
  String? _selectedLotSize;
  String? _selectedBudget;
  bool _isRestoringSavedProperties = true;

  @override
  void initState() {
    super.initState();
    appPropertiesNotifier.addListener(_syncAvailableProperties);
    appNegrosPlacesNotifier.addListener(_syncNegrosPlaces);
    appSubscriptionNotifier.addListener(_handleSubscriptionChanged);
    unawaited(_restoreSavedProperties());
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
      _resolveSavedProperties();
    });
  }

  void _syncNegrosPlaces() {
    if (!mounted) return;
    setState(() {
      _negrosPlaces = List<NegrosPlace>.from(appNegrosPlacesNotifier.value);
    });
  }

  void _handleSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _restoreSavedProperties() async {
    final Set<String> savedPropertyIds =
        await SavedPropertyStorageService.loadSavedPropertyIds();
    if (!mounted) return;

    setState(() {
      _savedPropertyIds
        ..clear()
        ..addAll(savedPropertyIds);
      _isRestoringSavedProperties = false;
      _resolveSavedProperties();
    });
  }

  void _resolveSavedProperties() {
    _savedProperties
      ..clear()
      ..addAll(
        SavedPropertyStorageService.resolveSavedProperties(
          availableProperties: _availableProperties,
          savedPropertyIds: _savedPropertyIds,
        ),
      );
  }

  List<Property> get _filteredProperties {
    final List<Property> filtered = filterHomeProperties(
      availableProperties: _availableProperties,
      negrosPlaces: _negrosPlaces,
      searchQuery: _searchController.text,
      selectedLocation: _selectedLocation,
      selectedLotSize: _selectedLotSize,
      selectedBudget: _selectedBudget,
    );
    if (!widget.savedOnly) return filtered;

    return filtered.where(_savedProperties.contains).toList(growable: false);
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedLocation = null;
      _selectedLotSize = null;
      _selectedBudget = null;
    });
  }

  Future<void> _toggleSavedProperty(Property property) async {
    final bool isAlreadySaved = _savedProperties.contains(property);
    if (SavedPropertyStorageService.shouldShowUpgradePrompt(
      isAlreadySaved: isAlreadySaved,
      isPremium: appSubscriptionNotifier.value.isPremium,
      savedCount: _savedProperties.length,
      freeLimit: freeSavedPropertiesLimit,
    )) {
      await showSavedPropertiesUpgradeSheet(
        context: context,
        onViewPlans: () {
          unawaited(openSubscriptionPage(context));
        },
      );
      return;
    }

    setState(() {
      SavedPropertyStorageService.toggleSavedProperty(
        property: property,
        savedProperties: _savedProperties,
        savedPropertyIds: _savedPropertyIds,
      );
    });
    await SavedPropertyStorageService.saveSavedPropertyIds(_savedPropertyIds);
  }

  void _openDetails(Property property) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyDetailsScreen(
          property: property,
          isSaved: _savedProperties.contains(property),
          onToggleSave: () => unawaited(_toggleSavedProperty(property)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Property> properties = _filteredProperties;

    return AppScaffoldShell(
      title: widget.title,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            SearchSection(
              searchController: _searchController,
              onSearchChanged: (_) => setState(() {}),
              selectedLocation: _selectedLocation,
              locationItems: homeLocationFilterItems(_negrosPlaces),
              selectedLotSize: _selectedLotSize,
              selectedBudget: _selectedBudget,
              onLocationChanged: (value) {
                setState(() => _selectedLocation = value);
              },
              onLotSizeChanged: (value) {
                setState(() => _selectedLotSize = value);
              },
              onBudgetChanged: (value) {
                setState(() => _selectedBudget = value);
              },
              onResetFilters: _resetFilters,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.savedOnly && _isRestoringSavedProperties
                  ? const Center(child: CircularProgressIndicator())
                  : properties.isEmpty
                  ? EmptyState(
                      icon: widget.savedOnly
                          ? Icons.favorite_border_rounded
                          : Icons.search_off,
                      message: widget.savedOnly
                          ? 'No saved properties match these filters.'
                          : 'No properties match your search.',
                      subtitle: 'Try changing your search or filters.',
                    )
                  : ListView.builder(
                      itemCount: properties.length,
                      itemBuilder: (context, index) {
                        final Property property = properties[index];
                        return PropertyTile(
                          property: property,
                          isSaved: _savedProperties.contains(property),
                          onToggleSave: () {
                            unawaited(_toggleSavedProperty(property));
                          },
                          onOpenDetails: () => _openDetails(property),
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
