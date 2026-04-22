import 'package:flutter/material.dart';

class MarkerLegend extends StatelessWidget {
  const MarkerLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.location_on),
        SizedBox(width: 4),
        Text('Property'),
      ],
    );
  }
}
