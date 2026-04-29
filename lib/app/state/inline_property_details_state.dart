import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../features/properties/data/datasources/shared_properties.dart';

class InlinePropertyDetailsState {
  final Property property;
  final bool isSaved;
  final VoidCallback onToggleSave;

  const InlinePropertyDetailsState({
    required this.property,
    required this.isSaved,
    required this.onToggleSave,
  });
}

final ValueNotifier<InlinePropertyDetailsState?>
    appInlinePropertyDetailsNotifier =
    ValueNotifier<InlinePropertyDetailsState?>(null);
