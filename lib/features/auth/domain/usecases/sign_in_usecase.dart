import '../entities/auth_user_entity.dart';
import '../repositories/auth_repository.dart';

class SignInUsecase {
  const SignInUsecase(this.repository);

  final AuthRepository repository;

  Future<AuthUserEntity> call({
    required String email,
    required String password,
  }) {
    return repository.signIn(email: email, password: password);
  }
}
