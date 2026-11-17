import '../entities/auth_user_entity.dart';

abstract interface class AuthRepository {
  Future<AuthUserEntity?> getCurrentUser();

  Future<AuthUserEntity> signIn({
    required String email,
    required String password,
  });

  Future<AuthUserEntity> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  });

  Future<void> signOut();

  Future<void> resetPassword(String email);

  Future<void> updatePassword(String newPassword);

  Future<String> getUserRole(String userId);

  Future<bool> emailExists(String email);
}
