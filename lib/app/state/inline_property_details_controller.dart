import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/properties/data/datasources/shared_properties.dart';
import '../../features/properties/presentation/widgets/property_image.dart';
import 'inline_property_details_state.dart';

void showInlinePropertyDetails({
  required BuildContext context,
  required Property property,
  required bool isSaved,
  required VoidCallback onToggleSave,
}) {
  unawaited(precachePropertyImage(context, property, height: 300));
  unawaited(recordPropertyView(property));
  appInlinePropertyDetailsNotifier.value = InlinePropertyDetailsState(
    property: property,
    isSaved: isSaved,
    onToggleSave: onToggleSave,
  );
}

void hideInlinePropertyDetails() {
  appInlinePropertyDetailsNotifier.value = null;
}
