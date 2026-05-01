import 'package:flutter/material.dart';

import '../../../../core/widgets/app_dropdown.dart';

class SearchSection extends StatelessWidget {
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
              children: <Widget>[
                Text(
                  'Filters',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                  items: const <String>[
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
                  items: const <String>['Below ₱1M', '₱1M - ₱3M', 'Above ₱3M'],
                  onChanged: onBudgetChanged,
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
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
    final bool isCompactPhone = MediaQuery.sizeOf(context).width < 360;
    final double iconBoxSize = isCompactPhone ? 40 : 44;
    final double verticalPadding = isCompactPhone ? 8 : 10;
    final int activeFilterCount = <String?>[
      selectedLocation,
      selectedLotSize,
      selectedBudget,
    ].where((value) => value != null).length;
    final Color searchSurface = isLightTheme
        ? Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: 0.075),
            theme.colorScheme.surface,
          )
        : const Color.fromARGB(255, 199, 212, 228);
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
        boxShadow: <BoxShadow>[
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
          prefixIcon: Icon(Icons.search, color: mutedColor, size: 21),
          prefixIconConstraints: BoxConstraints(
            minWidth: iconBoxSize,
            minHeight: iconBoxSize,
          ),
          suffixIcon: IconButton(
            tooltip: 'Filters',
            onPressed: () => _showFilterSheet(context),
            constraints: BoxConstraints(
              minWidth: iconBoxSize,
              minHeight: iconBoxSize,
            ),
            icon: Badge(
              isLabelVisible: activeFilterCount > 0,
              label: Text(activeFilterCount.toString()),
              child: Icon(Icons.tune_rounded, color: mutedColor),
            ),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: verticalPadding,
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
