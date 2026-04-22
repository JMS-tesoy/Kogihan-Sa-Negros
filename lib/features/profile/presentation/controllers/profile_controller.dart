import 'package:flutter/foundation.dart';

import '../../domain/entities/profile_entity.dart';
import '../../domain/usecases/get_profile_usecase.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({this.getProfileUsecase});

  final GetProfileUsecase? getProfileUsecase;

  ProfileEntity? _profile;

  ProfileEntity? get profile => _profile;

  Future<void> load() async {
    _profile = await getProfileUsecase?.call();
    notifyListeners();
  }
}
