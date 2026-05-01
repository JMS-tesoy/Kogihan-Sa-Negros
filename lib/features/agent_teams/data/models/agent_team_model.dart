import '../../domain/entities/agent_team_entity.dart';
import 'agent_team_member_model.dart';

class AgentTeamModel extends AgentTeamEntity {
  const AgentTeamModel({
    required super.id,
    required super.name,
    super.description,
    super.logoUrl,
    super.specialization,
    super.members,
  });

  factory AgentTeamModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic> membersJson =
        json['team_members'] as List<dynamic>? ?? <dynamic>[];
    return AgentTeamModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      logoUrl: json['logo_url'] as String?,
      specialization: json['specialization'] as String? ?? '',
      members: membersJson
          .map(
            (m) => AgentTeamMemberModel.fromJson(
              Map<String, dynamic>.from(m as Map),
            ),
          )
          .toList(),
    );
  }
}
