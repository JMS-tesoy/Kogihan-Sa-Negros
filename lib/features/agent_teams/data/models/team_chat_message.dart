class TeamChatMessage {
  const TeamChatMessage({
    required this.id,
    required this.teamId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentPath,
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentSizeBytes,
  });

  factory TeamChatMessage.fromMap(Map<String, dynamic> map) {
    return TeamChatMessage(
      id: map['id'] as String? ?? '',
      teamId: map['team_id'] as String? ?? '',
      senderId: map['sender_id'] as String? ?? '',
      senderName: map['sender_name'] as String? ?? 'Agent',
      body: map['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      attachmentUrl: map['attachment_url'] as String?,
      attachmentPath: map['attachment_path'] as String?,
      attachmentName: map['attachment_name'] as String?,
      attachmentMimeType: map['attachment_mime_type'] as String?,
      attachmentSizeBytes: _parseAttachmentSize(map['attachment_size_bytes']),
    );
  }

  final String id;
  final String teamId;
  final String senderId;
  final String senderName;
  final String body;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentPath;
  final String? attachmentName;
  final String? attachmentMimeType;
  final int? attachmentSizeBytes;

  bool get hasAttachment => (attachmentUrl ?? '').trim().isNotEmpty;

  bool get attachmentIsImage =>
      (attachmentMimeType ?? '').toLowerCase().startsWith('image/');

  String get attachmentDisplayName {
    final String name = (attachmentName ?? '').trim();
    return name.isNotEmpty ? name : 'Attachment';
  }
}

int? _parseAttachmentSize(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(value.toString());
}
