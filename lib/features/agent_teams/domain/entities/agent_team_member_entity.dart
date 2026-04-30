class AgentTeamMemberEntity {
  const AgentTeamMemberEntity({
    required this.id,
    required this.name,
    this.userId,
    this.role = '',
    this.avatarUrl,
    this.phone,
    this.email,
  });

  final String id;
  final String name;
  final String? userId;
  final String role;
  final String? avatarUrl;
  final String? phone;
  final String? email;
}
