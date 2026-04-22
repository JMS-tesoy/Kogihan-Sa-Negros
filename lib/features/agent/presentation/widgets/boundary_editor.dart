import 'package:flutter/material.dart';

class BoundaryEditor extends StatelessWidget {
  const BoundaryEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Text('Boundary editor'),
    );
  }
}
