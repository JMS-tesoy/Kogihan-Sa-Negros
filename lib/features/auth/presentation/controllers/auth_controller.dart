import 'package:flutter/foundation.dart';

import '../../domain/entities/auth_user_entity.dart';
import '../../domain/usecases/get_current_user_usecase.dart';
import '../../domain/usecases/sign_in_usecase.dart';
import '../../domain/usecases/sign_out_usecase.dart';

class AuthController extends ChangeNotifier {
  AuthController({
    this.signInUsecase,
    this.signOutUsecase,
    this.getCurrentUserUsecase,
  });

  final SignInUsecase? signInUsecase;
  final SignOutUsecase? signOutUsecase;
  final GetCurrentUserUsecase? getCurrentUserUsecase;

  AuthUserEntity? _user;
  bool _isLoading = false;

  AuthUserEntity? get user => _user;
  bool get isLoading => _isLoading;

  Future<void> loadCurrentUser() async {
    _isLoading = true;
    notifyListeners();
    _user = await getCurrentUserUsecase?.call();
    _isLoading = false;
    notifyListeners();
  }
}
