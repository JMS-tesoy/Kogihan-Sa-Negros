import '../entities/agent_team_entity.dart';

abstract interface class AgentTeamsRepository {
  Future<List<AgentTeamEntity>> getAgentTeams();
  Future<AgentTeamEntity?> getAgentTeamById(String id);
}
