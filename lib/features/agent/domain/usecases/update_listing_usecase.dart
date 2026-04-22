import '../repositories/agent_repository.dart';

class UpdateListingUsecase {
  const UpdateListingUsecase(this.repository);

  final AgentRepository repository;

  Future<void> call(String listingId, Map<String, Object?> values) {
    return repository.updateListing(listingId, values);
  }
}
