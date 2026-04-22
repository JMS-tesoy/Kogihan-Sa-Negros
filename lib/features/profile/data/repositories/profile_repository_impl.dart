import '../../domain/entities/profile_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/profile_model.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  ProfileRepositoryImpl({ProfileRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? ProfileRemoteDatasource();

  final ProfileRemoteDatasource _remoteDatasource;

  @override
  Future<ProfileEntity?> getProfile() {
    return _remoteDatasource.getProfile();
  }

  @override
  Future<void> updateProfile(ProfileEntity profile) {
    final model = ProfileModel(
      id: profile.id,
      name: profile.name,
      email: profile.email,
      phone: profile.phone,
      avatarUrl: profile.avatarUrl,
    );
    return _remoteDatasource.updateProfile(model);
  }
}
