import '../entities/profile_entity.dart';
import '../repositories/profile_repository.dart';

class UpdateProfileUsecase {
  const UpdateProfileUsecase(this.repository);

  final ProfileRepository repository;

  Future<void> call(ProfileEntity profile) {
    return repository.updateProfile(profile);
  }
}
