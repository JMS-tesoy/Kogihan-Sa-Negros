import 'package:flutter/material.dart';

class MapStyleToggle extends StatelessWidget {
  const MapStyleToggle({
    super.key,
    required this.isSatellite,
    required this.onChanged,
  });

  final bool isSatellite;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Satellite'),
      value: isSatellite,
      onChanged: onChanged,
    );
  }
}
