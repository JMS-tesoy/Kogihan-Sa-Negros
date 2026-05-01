import 'package:flutter/foundation.dart';

import '../../domain/entities/profile_entity.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({
    required GetProfileUsecase getProfileUsecase,
    required UpdateProfileUsecase updateProfileUsecase,
  }) : _getProfileUsecase = getProfileUsecase,
       _updateProfileUsecase = updateProfileUsecase;

  final GetProfileUsecase _getProfileUsecase;
  final UpdateProfileUsecase _updateProfileUsecase;

  ProfileEntity? _profile;
  bool _isLoading = false;
  String? _error;

  ProfileEntity? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _profile = await _getProfileUsecase();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> update(ProfileEntity profile) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _updateProfileUsecase(profile);
      _profile = profile;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
