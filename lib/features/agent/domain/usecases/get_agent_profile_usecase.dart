import '../entities/agent_profile_entity.dart';
import '../repositories/agent_repository.dart';

class GetAgentProfileUsecase {
  const GetAgentProfileUsecase(this.repository);

  final AgentRepository repository;

  Future<AgentProfileEntity?> call() {
    return repository.getAgentProfile();
  }
}
