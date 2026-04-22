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
  Future<void> signOut() {
    return _remoteDatasource.signOut();
  }
}
