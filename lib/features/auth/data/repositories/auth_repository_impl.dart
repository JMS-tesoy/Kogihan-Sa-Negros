import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({AuthRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? AuthRemoteDatasource();

  final AuthRemoteDatasource _remoteDatasource;

  @override
  Future<AuthUserEntity?> getCurrentUser() {
    return _remoteDatasource.getCurrentUser();
  }

  @override
  Future<AuthUserEntity> signIn({
    required String email,
    required String password,
  }) {
    return _remoteDatasource.signIn(email: email, password: password);
  }

  @override
  Future<AuthUserEntity> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
  }) {
    return _remoteDatasource.signUp(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
    );
  }

  @override
  Future<void> signOut() {
    return _remoteDatasource.signOut();
  }

  @override
  Future<void> resetPassword(String email) {
    return _remoteDatasource.resetPassword(email);
  }

  @override
  Future<void> updatePassword(String newPassword) {
    return _remoteDatasource.updatePassword(newPassword);
  }

  @override
  Future<String> getUserRole(String userId) {
    return _remoteDatasource.getUserRole(userId);
  }

  @override
  Future<bool> emailExists(String email) {
    return _remoteDatasource.emailExists(email);
  }
}
