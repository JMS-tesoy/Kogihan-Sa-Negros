import 'package:flutter/material.dart';

class PropertyMapPreview extends StatelessWidget {
  const PropertyMapPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.map, size: 48),
    );
  }
}
