import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  bool _isReady = false;

  bool get isReady => _isReady;

  void markReady() {
    if (_isReady) {
      return;
    }

    _isReady = true;
    notifyListeners();
  }
}
