import 'package:flutter/material.dart';

import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/property_gallery.dart';

class PropertyGalleryScreen extends StatelessWidget {
  const PropertyGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffoldShell(
      title: 'Gallery',
      body: PropertyGallery(images: <Never>[]),
    );
  }
}
