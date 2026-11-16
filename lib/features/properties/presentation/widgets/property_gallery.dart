import 'package:flutter/material.dart';

import '../../domain/entities/property_image_entity.dart';

class PropertyGallery extends StatefulWidget {
  const PropertyGallery({
    super.key,
    required this.images,
    this.initialPage = 0,
  });

  final List<PropertyImageEntity> images;
  final int initialPage;

  @override
  State<PropertyGallery> createState() => _PropertyGalleryState();
}

class _PropertyGalleryState extends State<PropertyGallery> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.images.isEmpty
          ? 0
          : widget.initialPage.clamp(0, widget.images.length - 1).toInt(),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const Center(child: Icon(Icons.image, size: 48));
    }

    return PageView(
      controller: _pageController,
      children: widget.images.map((image) {
        return Image.network(image.url, fit: BoxFit.cover);
      }).toList(),
    );
  }
}
