import '../../../../shared/models/uploaded_media.dart';
import '../../domain/entities/agent_profile_entity.dart';
import '../../domain/repositories/agent_repository.dart';
import '../datasources/agent_remote_datasource.dart';

class AgentRepositoryImpl implements AgentRepository {
  AgentRepositoryImpl({AgentRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? AgentRemoteDatasource();

  final AgentRemoteDatasource _remoteDatasource;

  @override
  Future<AgentProfileEntity?> getAgentProfile() {
    return _remoteDatasource.getAgentProfile();
  }

  @override
  Future<void> createListing(Map<String, Object?> values) {
    return _remoteDatasource.createListing(values);
  }

  @override
  Future<void> updateListing(String listingId, Map<String, Object?> values) {
    return _remoteDatasource.updateListing(listingId, values);
  }

  @override
  Future<List<UploadedMedia>> uploadListingImages(List<String> paths) {
    return _remoteDatasource.uploadListingImages(paths);
  }
}
