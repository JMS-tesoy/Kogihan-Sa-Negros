enum ModerationCaseType { submission, report }

class ModerationCase {
  const ModerationCase({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.createdAt,
    this.description,
    this.reason,
    this.propertyId,
    this.agentId,
    this.imageUrl,
  });

  factory ModerationCase.fromProperty(Map<String, dynamic> map) {
    return ModerationCase(
      id: map['id']?.toString() ?? '',
      type: ModerationCaseType.submission,
      title: (map['title'] ?? 'Untitled listing').toString(),
      subtitle: (map['location'] ?? '').toString(),
      status: (map['status'] ?? 'pending').toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      description: _optionalString(map['description']),
      propertyId: map['id']?.toString(),
      agentId: _optionalString(map['agent_id']),
      imageUrl: _optionalString(map['image_url']),
    );
  }

  factory ModerationCase.fromReport(Map<String, dynamic> map) {
    return ModerationCase(
      id: map['id']?.toString() ?? '',
      type: ModerationCaseType.report,
      title: (map['property_title'] ?? 'Reported listing').toString(),
      subtitle: (map['reporter_name'] ?? 'Community report').toString(),
      status: (map['status'] ?? 'pending').toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      description: _optionalString(map['description']),
      reason: _optionalString(map['reason']),
      propertyId: _optionalString(map['reported_property_id']),
      agentId: _optionalString(map['reported_user_id']),
      imageUrl: _optionalString(map['property_image_url']),
    );
  }

  final String id;
  final ModerationCaseType type;
  final String title;
  final String subtitle;
  final String status;
  final DateTime createdAt;
  final String? description;
  final String? reason;
  final String? propertyId;
  final String? agentId;
  final String? imageUrl;

  bool get isPending => status == 'pending';

  static String? _optionalString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class ModerationAuditEntry {
  const ModerationAuditEntry({
    required this.id,
    required this.decision,
    required this.reason,
    required this.previousStatus,
    required this.newStatus,
    required this.createdAt,
  });

  factory ModerationAuditEntry.fromMap(Map<String, dynamic> map) {
    return ModerationAuditEntry(
      id: map['id']?.toString() ?? '',
      decision: (map['decision'] ?? '').toString(),
      reason: (map['reason'] ?? '').toString(),
      previousStatus: (map['previous_status'] ?? '').toString(),
      newStatus: (map['new_status'] ?? '').toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  final String id;
  final String decision;
  final String reason;
  final String previousStatus;
  final String newStatus;
  final DateTime createdAt;
}
