import 'package:flutter/material.dart';

class MediaUploadGrid extends StatelessWidget {
  const MediaUploadGrid({
    super.key,
    this.items = const <String>[],
  });

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final item in items) Chip(label: Text(item)),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('Add media'),
        ),
      ],
    );
  }
}
