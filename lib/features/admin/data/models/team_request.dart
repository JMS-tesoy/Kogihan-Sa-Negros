class TeamRequest {
  final String id;
  final String userId;
  final String teamId;
  final String teamName;
  final String requesterName;
  final String requesterEmail;
  final String status;
  final DateTime? createdAt;

  const TeamRequest({
    required this.id,
    required this.userId,
    required this.teamId,
    required this.teamName,
    required this.requesterName,
    required this.requesterEmail,
    required this.status,
    this.createdAt,
  });

  factory TeamRequest.fromMap(Map<String, dynamic> map) {
    final Object? team = map['agent_teams'];
    final Object? profile = map['profiles'];

    Map<String, dynamic>? teamMap;
    if (team is Map) {
      teamMap = Map<String, dynamic>.from(team);
    } else if (team is List && team.isNotEmpty) {
      teamMap = Map<String, dynamic>.from(team.first as Map);
    }

    Map<String, dynamic>? profileMap;
    if (profile is Map) {
      profileMap = Map<String, dynamic>.from(profile);
    } else if (profile is List && profile.isNotEmpty) {
      profileMap = Map<String, dynamic>.from(profile.first as Map);
    }

    return TeamRequest(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      teamId: map['team_id']?.toString() ?? '',
      teamName: teamMap?['name']?.toString().trim() ?? 'Unknown Team',
      requesterName: profileMap?['full_name']?.toString().trim() ?? 'Unknown',
      requesterEmail: profileMap?['email']?.toString().trim() ?? '',
      status: (map['status'] ?? 'pending').toString().trim(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}
