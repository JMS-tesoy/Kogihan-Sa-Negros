import 'agent_team_member_entity.dart';

class AgentTeamEntity {
  const AgentTeamEntity({
    required this.id,
    required this.name,
    this.description = '',
    this.logoUrl,
    this.specialization = '',
    this.members = const <AgentTeamMemberEntity>[],
  });

  final String id;
  final String name;
  final String description;
  final String? logoUrl;
  final String specialization;
  final List<AgentTeamMemberEntity> members;
}