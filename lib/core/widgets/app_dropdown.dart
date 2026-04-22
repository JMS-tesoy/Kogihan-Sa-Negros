import 'package:flutter/material.dart';

class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.labelText,
  });

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final T? value;
  final String? labelText;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: labelText),
    );
  }
}

class FilterDropdown extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isLightTheme = Theme.of(context).brightness == Brightness.light;
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
            ? <BoxShadow>[
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
