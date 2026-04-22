import 'package:flutter/material.dart';

class PropertyContactBar extends StatelessWidget {
  const PropertyContactBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.message),
            label: const Text('Message'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.call),
            label: const Text('Call'),
          ),
        ),
      ],
    );
  }
}
