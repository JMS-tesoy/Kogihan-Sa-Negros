import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/featured_listings_section.dart';
import '../widgets/home_header.dart';
import '../widgets/nearby_properties_section.dart';
import '../widgets/quick_filter_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Home',
      actions: <Widget>[
        IconButton(
          tooltip: 'Search',
          onPressed: () => Navigator.of(context).pushNamed(RouteNames.search),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: 'Map',
          onPressed: () => Navigator.of(context).pushNamed(RouteNames.map),
          icon: const Icon(Icons.map),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          HomeHeader(),
          SizedBox(height: 16),
          QuickFilterBar(),
          SizedBox(height: 24),
          FeaturedListingsSection(),
          SizedBox(height: 24),
          NearbyPropertiesSection(),
        ],
      ),
    );
  }
}
