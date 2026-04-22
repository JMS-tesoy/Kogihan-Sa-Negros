import 'package:flutter/material.dart';

class SearchResultTabs extends StatelessWidget {
  const SearchResultTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabBar(
      tabs: <Widget>[
        Tab(text: 'Properties'),
        Tab(text: 'Agents'),
        Tab(text: 'Places'),
      ],
    );
  }
}
