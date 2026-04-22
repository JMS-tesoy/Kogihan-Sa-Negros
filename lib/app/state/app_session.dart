import 'package:flutter/foundation.dart';

import '../../shared/models/app_user.dart';

class AppSession extends ChangeNotifier {
  AppUser? _user;

  AppUser? get user => _user;
  bool get isSignedIn => _user != null;

  void setUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  void clear() {
    _user = null;
    notifyListeners();
  }
}
