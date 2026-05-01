import '../../domain/entities/agent_team_entity.dart';
import '../../domain/repositories/agent_teams_repository.dart';
import '../datasources/agent_teams_remote_datasource.dart';

class AgentTeamsRepositoryImpl implements AgentTeamsRepository {
  AgentTeamsRepositoryImpl({AgentTeamsRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? AgentTeamsRemoteDatasource();

  final AgentTeamsRemoteDatasource _remoteDatasource;

  @override
  Future<List<AgentTeamEntity>> getAgentTeams() =>
      _remoteDatasource.getAgentTeams();

  @override
  Future<AgentTeamEntity?> getAgentTeamById(String id) =>
      _remoteDatasource.getAgentTeamById(id);
}
