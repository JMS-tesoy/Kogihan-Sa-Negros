import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import '../../../properties/data/services/saved_property_storage_service.dart';
import '../../../properties/presentation/widgets/saved_properties_upgrade_sheet.dart';
import '../../../subscription/data/services/subscription_service.dart';
import '../../../subscription/presentation/navigation/subscription_navigation.dart';
import 'map_tab.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.selectedProperty});

  final Property? selectedProperty;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Set<String> _savedPropertyIds = <String>{};
  final Set<Property> _savedProperties = <Property>{};

  @override
  void initState() {
    super.initState();
    appPropertiesNotifier.addListener(_syncSavedProperties);
    appSubscriptionNotifier.addListener(_handleSubscriptionChanged);
    unawaited(_restoreSavedProperties());
  }

  @override
  void dispose() {
    appPropertiesNotifier.removeListener(_syncSavedProperties);
    appSubscriptionNotifier.removeListener(_handleSubscriptionChanged);
    super.dispose();
  }

  Future<void> _restoreSavedProperties() async {
    final Set<String> savedPropertyIds =
        await SavedPropertyStorageService.loadSavedPropertyIds();
    if (!mounted) return;

    setState(() {
      _savedPropertyIds
        ..clear()
        ..addAll(savedPropertyIds);
      _resolveSavedProperties();
    });
  }

  void _syncSavedProperties() {
    if (!mounted) return;
    setState(_resolveSavedProperties);
  }

  void _resolveSavedProperties() {
    _savedProperties
      ..clear()
      ..addAll(
        SavedPropertyStorageService.resolveSavedProperties(
          availableProperties: appPropertiesNotifier.value,
          savedPropertyIds: _savedPropertyIds,
        ),
      );
  }

  void _handleSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _toggleSavedProperty(Property property) {
    final bool isAlreadySaved = _savedProperties.contains(property);
    if (SavedPropertyStorageService.shouldShowUpgradePrompt(
      isAlreadySaved: isAlreadySaved,
      isPremium: appSubscriptionNotifier.value.isPremium,
      savedCount: _savedProperties.length,
      freeLimit: freeSavedPropertiesLimit,
    )) {
      unawaited(
        showSavedPropertiesUpgradeSheet(
          context: context,
          onViewPlans: () {
            unawaited(openSubscriptionPage(context));
          },
        ),
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
    unawaited(
      SavedPropertyStorageService.saveSavedPropertyIds(_savedPropertyIds),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Map',
      body: MapTab(
        savedProperties: _savedProperties,
        onToggleSave: _toggleSavedProperty,
        initialSelectedPropertyId: widget.selectedProperty?.id,
      ),
    );
  }
}
