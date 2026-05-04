enum AppNotificationType {
  propertyUpdate,
  inquiryReply,
  savedProperty,
  systemNotice,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.relatedPropertyId,
  });

  final String id;
  final String userId;
  final String title;
  final String message;
  final AppNotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? relatedPropertyId;

  AppNotification copyWith({
    String? id,
    String? userId,
    String? title,
    String? message,
    AppNotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    String? relatedPropertyId,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      relatedPropertyId: relatedPropertyId ?? this.relatedPropertyId,
    );
  }

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    return AppNotification(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String? ?? '',
      message: map['message'] as String? ?? '',
      type: _typeFromDatabase(map['type'] as String?),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      isRead: map['is_read'] as bool? ?? false,
      relatedPropertyId: map['related_property_id'] as String?,
    );
  }

  static AppNotificationType _typeFromDatabase(String? value) {
    switch (value) {
      case 'property_update':
        return AppNotificationType.propertyUpdate;
      case 'inquiry_reply':
        return AppNotificationType.inquiryReply;
      case 'saved_property':
        return AppNotificationType.savedProperty;
      case 'system_notice':
      default:
        return AppNotificationType.systemNotice;
    }
  }
}
