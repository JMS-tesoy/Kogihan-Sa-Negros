import '../entities/profile_entity.dart';
import '../repositories/profile_repository.dart';

class GetProfileUsecase {
  const GetProfileUsecase(this.repository);

  final ProfileRepository repository;

  Future<ProfileEntity?> call() {
    return repository.getProfile();
  }
}
