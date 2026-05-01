import 'package:flutter/material.dart';

import '../../domain/entities/property_image_entity.dart';

class PropertyGallery extends StatelessWidget {
  const PropertyGallery({super.key, required this.images});

  final List<PropertyImageEntity> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return const Center(child: Icon(Icons.image, size: 48));
    }

    return PageView(
      children: images.map((image) {
        return Image.network(image.url, fit: BoxFit.cover);
      }).toList(),
    );
  }
}
