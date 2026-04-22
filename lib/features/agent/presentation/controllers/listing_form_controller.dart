import 'package:flutter/foundation.dart';

class ListingFormController extends ChangeNotifier {
  bool _isSaving = false;

  bool get isSaving => _isSaving;

  void setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }
}
