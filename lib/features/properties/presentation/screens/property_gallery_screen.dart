import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../../domain/entities/property_image_entity.dart';
import '../widgets/property_gallery.dart';

class PropertyGalleryArgs {
  const PropertyGalleryArgs({required this.images, this.initialIndex = 0});

  final List<PropertyImageEntity> images;
  final int initialIndex;
}

class PropertyGalleryScreen extends StatelessWidget {
  const PropertyGalleryScreen({super.key, required this.arguments});

  final PropertyGalleryArgs arguments;

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Gallery',
      body: PropertyGallery(
        images: arguments.images,
        initialPage: arguments.initialIndex,
      ),
    );
  }
}
