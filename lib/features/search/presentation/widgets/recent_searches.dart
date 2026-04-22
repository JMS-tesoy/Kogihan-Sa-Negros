import 'package:flutter/material.dart';

class RecentSearches extends StatelessWidget {
  const RecentSearches({
    super.key,
    this.searches = const <String>[],
  });

  final List<String> searches;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: searches.map((search) => Chip(label: Text(search))).toList(),
    );
  }
}
