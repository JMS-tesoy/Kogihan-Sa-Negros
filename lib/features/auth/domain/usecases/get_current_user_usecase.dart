import '../entities/auth_user_entity.dart';
import '../repositories/auth_repository.dart';

class GetCurrentUserUsecase {
  const GetCurrentUserUsecase(this.repository);

  final AuthRepository repository;

  Future<AuthUserEntity?> call() {
    return repository.getCurrentUser();
  }
}
