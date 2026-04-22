import '../models/auth_user_model.dart';

class AuthRemoteDatasource {
  Future<AuthUserModel?> getCurrentUser() async {
    return null;
  }

  Future<AuthUserModel> signIn({
    required String email,
    required String password,
  }) async {
    return AuthUserModel(id: email, email: email);
  }

  Future<void> signOut() async {}
}
