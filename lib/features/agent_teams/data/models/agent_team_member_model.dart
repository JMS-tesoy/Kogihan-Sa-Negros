import '../../domain/entities/agent_team_member_entity.dart';

class AgentTeamMemberModel extends AgentTeamMemberEntity {
  const AgentTeamMemberModel({
    required super.id,
    required super.name,
    super.role,
    super.avatarUrl,
    super.phone,
    super.email,
  });

  factory AgentTeamMemberModel.fromJson(Map<String, dynamic> json) {
    return AgentTeamMemberModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      role: json['role'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
    );
  }
}