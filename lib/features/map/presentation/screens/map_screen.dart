import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/map_view.dart';
import '../widgets/marker_legend.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffoldShell(
      title: 'Map',
      body: Stack(
        children: <Widget>[
          Positioned.fill(child: MapView()),
          Positioned(
            left: 16,
            bottom: 16,
            child: MarkerLegend(),
          ),
        ],
      ),
    );
  }
}
