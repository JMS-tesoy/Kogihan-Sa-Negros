import 'package:flutter/material.dart';

class PropertyMapCard extends StatelessWidget {
  const PropertyMapCard({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(leading: const Icon(Icons.home), title: Text(title)),
    );
  }
}
