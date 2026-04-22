import '../../../../shared/models/uploaded_media.dart';
import '../entities/agent_profile_entity.dart';

abstract interface class AgentRepository {
  Future<AgentProfileEntity?> getAgentProfile();

  Future<void> createListing(Map<String, Object?> values);

  Future<void> updateListing(String listingId, Map<String, Object?> values);

  Future<List<UploadedMedia>> uploadListingImages(List<String> paths);
}
