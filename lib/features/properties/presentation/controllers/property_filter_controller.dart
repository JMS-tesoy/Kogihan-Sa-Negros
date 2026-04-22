import 'package:flutter/foundation.dart';

import '../../domain/entities/property_filter_entity.dart';

class PropertyFilterController extends ChangeNotifier {
  PropertyFilterEntity _filter = const PropertyFilterEntity();

  PropertyFilterEntity get filter => _filter;

  void update(PropertyFilterEntity filter) {
    _filter = filter;
    notifyListeners();
  }
}
