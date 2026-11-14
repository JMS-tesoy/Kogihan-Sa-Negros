class AgentProfile {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? avatarUrl;
  final String? teamId;
  final String? teamName;
  final String? role;

  const AgentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.avatarUrl,
    this.teamId,
    this.teamName,
    this.role,
  });

  factory AgentProfile.fromMap(Map<String, dynamic> map) {
    final Object? team = map['agent_teams'];

    final String? teamName = team is Map
        ? (team['name']?.toString().trim().isEmpty ?? true)
              ? null
              : team['name']?.toString().trim()
        : null;

    final String? teamId = team is Map
        ? (team['id']?.toString().trim().isEmpty ?? true)
              ? null
              : team['id']?.toString().trim()
        : _toNullableString(map['team_id']);

    return AgentProfile(
      id: map['id']?.toString() ?? '',
      fullName: (map['full_name'] ?? '').toString().trim(),
      email: (map['email'] ?? '').toString().trim(),
      phone: (map['phone'] ?? '').toString().trim(),
      avatarUrl: _toNullableString(map['avatar_url']),
      teamId: teamId,
      teamName: teamName,
      role: _toNullableString(map['role']),
    );
  }

  static String? _toNullableString(dynamic value) {
    final String normalized = (value?.toString() ?? '').trim();
    return normalized.isEmpty ? null : normalized;
  }
}
