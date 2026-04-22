import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../../../core/widgets/app_search_field.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffoldShell(
      title: 'Search',
      body: Padding(
        padding: EdgeInsets.all(16),
        child: AppSearchField(hintText: 'Search everything'),
      ),
    );
  }
}
