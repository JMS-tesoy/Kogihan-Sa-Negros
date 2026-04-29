import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/state/inline_property_details_controller.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import '../../../properties/presentation/widgets/property_image.dart';
import '../../../properties/presentation/widgets/property_tile.dart';
import '../../../properties/presentation/widgets/recommended_properties_carousel.dart';
import '../widgets/active_filter_chip.dart';
import '../widgets/search_section.dart';
import '../widgets/sticky_search_header_delegate.dart';
import '../widgets/top_header.dart';

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