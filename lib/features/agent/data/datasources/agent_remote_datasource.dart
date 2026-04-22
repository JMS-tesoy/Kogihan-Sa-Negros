import '../../../../shared/models/uploaded_media.dart';
import '../models/agent_profile_model.dart';

class AgentRemoteDatasource {
  Future<AgentProfileModel?> getAgentProfile() async {
    return null;
  }

  Future<void> createListing(Map<String, Object?> values) async {}

  Future<void> updateListing(
    String listingId,
    Map<String, Object?> values,
  ) async {}

  Future<List<UploadedMedia>> uploadListingImages(List<String> paths) async {
    return paths
        .map(
          (path) => UploadedMedia(
            id: path,
            url: path,
            fileName: path.split('/').last,
          ),
        )
        .toList();
  }
}
