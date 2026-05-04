class TeamChatTeam {
  const TeamChatTeam({
    required this.id,
    required this.name,
    required this.specialization,
    required this.logoUrl,
  });

  factory TeamChatTeam.fromMap(Map<String, dynamic> map) {
    return TeamChatTeam(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed Team',
      specialization: map['specialization'] as String? ?? '',
      logoUrl: map['logo_url'] as String?,
    );
  }

  final String id;
  final String name;
  final String specialization;
  final String? logoUrl;
}
