import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../../properties/data/datasources/shared_properties.dart';
import 'map_tab.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key, this.selectedProperty});

  final Property? selectedProperty;

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Map',
      body: MapTab(
        savedProperties: const <Property>{},
        onToggleSave: (_) {},
        initialSelectedPropertyId: selectedProperty?.id,
      ),
    );
  }
}
