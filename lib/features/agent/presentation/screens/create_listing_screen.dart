import 'package:flutter/material.dart';

import '../../../properties/data/datasources/shared_properties.dart';
import 'property_form_page.dart';

class CreateListingScreen extends StatelessWidget {
  final Property? initialProperty;

  const CreateListingScreen({super.key, this.initialProperty});

  @override
  Widget build(BuildContext context) {
    return PropertyFormPage(initialProperty: initialProperty);
  }
}
