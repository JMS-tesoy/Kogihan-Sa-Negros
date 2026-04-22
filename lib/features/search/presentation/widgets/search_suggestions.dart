import 'package:flutter/material.dart';

class SearchSuggestions extends StatelessWidget {
  const SearchSuggestions({
    super.key,
    this.suggestions = const <String>[],
    this.onSelected,
  });

  final List<String> suggestions;
  final ValueChanged<String>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: suggestions.map((suggestion) {
        return ListTile(
          title: Text(suggestion),
          onTap: () => onSelected?.call(suggestion),
        );
      }).toList(),
    );
  }
}
