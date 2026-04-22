import '../entities/auth_user_entity.dart';

abstract interface class AuthRepository {
  Future<AuthUserEntity?> getCurrentUser();

  Future<AuthUserEntity> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}
