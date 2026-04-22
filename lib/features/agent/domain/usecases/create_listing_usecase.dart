import '../repositories/agent_repository.dart';

class CreateListingUsecase {
  const CreateListingUsecase(this.repository);

  final AgentRepository repository;

  Future<void> call(Map<String, Object?> values) {
    return repository.createListing(values);
  }
}
