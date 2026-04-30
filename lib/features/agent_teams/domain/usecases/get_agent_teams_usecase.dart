import '../entities/agent_team_entity.dart';
import '../repositories/agent_teams_repository.dart';

class GetAgentTeamsUsecase {
  const GetAgentTeamsUsecase(this.repository);

  final AgentTeamsRepository repository;

  Future<List<AgentTeamEntity>> call() => repository.getAgentTeams();
}