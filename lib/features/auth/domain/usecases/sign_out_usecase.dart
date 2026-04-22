import '../repositories/auth_repository.dart';

class SignOutUsecase {
  const SignOutUsecase(this.repository);

  final AuthRepository repository;

  Future<void> call() {
    return repository.signOut();
  }
}
