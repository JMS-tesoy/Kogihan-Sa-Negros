import 'package:flutter/foundation.dart';

class MapFilterController extends ChangeNotifier {
  String _query = '';

  String get query => _query;

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }
}
