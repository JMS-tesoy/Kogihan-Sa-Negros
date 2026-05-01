import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import '../../../properties/presentation/screens/property_details_screen.dart';
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

  void _openDetails(
    BuildContext context,
    Property property,
    Set<Property> savedProperties,
    ValueChanged<Property> onToggleSave,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PropertyDetailsScreen(
          property: property,
          isSaved: savedProperties.contains(property),
          onToggleSave: () => onToggleSave(property),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isCompactPhone = screenWidth < 360;
    final double horizontalPadding = isCompactPhone ? 12 : 16;
    final double toolbarHeight = isCompactPhone ? 74 : 84;
    final double searchBottomPadding = isCompactPhone ? 12 : 16;
    final double searchHeaderHeight = isCompactPhone ? 54 : 60;
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
    final String lotsHeaderTitle = hasActiveFilters
        ? 'Filtered Lots'
        : 'All Lots';

    return SafeArea(
      child: CustomScrollView(
        cacheExtent: 400,
        slivers: <Widget>[
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 10,
            floating: true,
            snap: true,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: toolbarHeight,
            flexibleSpace: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                10,
                horizontalPadding,
                10,
              ),
              child: const TopHeader(),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: StickySearchHeaderDelegate(
              height: searchHeaderHeight,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  0,
                  horizontalPadding,
                  searchBottomPadding,
                ),
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
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                0,
                horizontalPadding,
                12,
              ),
              sliver: SliverToBoxAdapter(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
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
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
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
                  onOpenDetails: (property) => _openDetails(
                    context,
                    property,
                    savedProperties,
                    onToggleSave,
                  ),
                  onPrecacheDetails: (context, property) {
                    unawaited(
                      precachePropertyImage(context, property, height: 300),
                    );
                  },
                ),
              ),
            ),
          if (properties.isNotEmpty)
            SliverToBoxAdapter(
              child: _LotsFilterSection(
                title: lotsHeaderTitle,
                properties: properties,
                savedProperties: savedProperties,
                onToggleSave: onToggleSave,
                onOpenDetails: (property) => _openDetails(
                  context,
                  property,
                  savedProperties,
                  onToggleSave,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _LotFilter { all, newlyListed, available, sold, mostViewed }

class _LotsFilterSection extends StatefulWidget {
  const _LotsFilterSection({
    required this.title,
    required this.properties,
    required this.savedProperties,
    required this.onToggleSave,
    required this.onOpenDetails,
  });

  final String title;
  final List<Property> properties;
  final Set<Property> savedProperties;
  final ValueChanged<Property> onToggleSave;
  final ValueChanged<Property> onOpenDetails;

  @override
  State<_LotsFilterSection> createState() => _LotsFilterSectionState();
}

class _LotsFilterSectionState extends State<_LotsFilterSection> {
  _LotFilter _selectedFilter = _LotFilter.all;

  List<Property> get _filteredProperties {
    final Iterable<Property> filteredProperties = widget.properties.where((
      property,
    ) {
      final String tag = property.tag.trim().toLowerCase();
      switch (_selectedFilter) {
        case _LotFilter.all:
          return true;
        case _LotFilter.newlyListed:
          return tag.contains('new');
        case _LotFilter.available:
          return !tag.contains('sold') &&
              !tag.contains('auction') &&
              !tag.contains('process') &&
              !tag.contains('pending') &&
              !tag.contains('reserved');
        case _LotFilter.sold:
          return tag.contains('sold');
        case _LotFilter.mostViewed:
          return property.viewCount > 0;
      }
    });

    final List<Property> result = filteredProperties.toList();
    if (_selectedFilter == _LotFilter.mostViewed) {
      result.sort(
        (first, second) => second.viewCount.compareTo(first.viewCount),
      );
    }
    return result;
  }

  String get _selectedTitle {
    switch (_selectedFilter) {
      case _LotFilter.all:
        return widget.title;
      case _LotFilter.newlyListed:
        return 'Newly Listed';
      case _LotFilter.available:
        return 'Available';
      case _LotFilter.sold:
        return 'Sold';
      case _LotFilter.mostViewed:
        return 'Most Viewed';
    }
  }

  Widget _filterChip(_LotFilter filter, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedFilter == filter,
      onSelected: (_) => setState(() => _selectedFilter = filter),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Property> filteredProperties = _filteredProperties;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _filterChip(_LotFilter.all, 'All'),
                const SizedBox(width: 8),
                _filterChip(_LotFilter.newlyListed, 'New'),
                const SizedBox(width: 8),
                _filterChip(_LotFilter.available, 'Available'),
                const SizedBox(width: 8),
                _filterChip(_LotFilter.sold, 'Sold'),
                const SizedBox(width: 8),
                _filterChip(_LotFilter.mostViewed, 'Most Viewed'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (filteredProperties.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('No ${_selectedTitle.toLowerCase()} lots found.'),
              ),
            )
          else
            ...filteredProperties.map(
              (property) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: PropertyTile(
                  property: property,
                  isSaved: widget.savedProperties.contains(property),
                  onToggleSave: () => widget.onToggleSave(property),
                  onOpenDetails: () => widget.onOpenDetails(property),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
