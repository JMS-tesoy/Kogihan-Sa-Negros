import 'notification_model.dart';

final List<AppNotification> mockNotifications = <AppNotification>[
  AppNotification(
    id: '1',
    userId: 'mock-user',
    title: 'Agent replied to your inquiry',
    message: 'Forest Ranger sent you a response about Martisan Beachside Lot.',
    type: AppNotificationType.inquiryReply,
    createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
    isRead: false,
  ),
  AppNotification(
    id: '2',
    userId: 'mock-user',
    title: 'Saved property updated',
    message: 'One of your saved properties has a new availability status.',
    type: AppNotificationType.savedProperty,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    isRead: false,
  ),
  AppNotification(
    id: '3',
    userId: 'mock-user',
    title: 'New property update',
    message: 'A beachside lot near the main road was recently updated.',
    type: AppNotificationType.propertyUpdate,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
  ),
  AppNotification(
    id: '4',
    userId: 'mock-user',
    title: 'Welcome to Kogihan Sa Negros',
    message: 'Your account is ready. Start browsing available properties.',
    type: AppNotificationType.systemNotice,
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    isRead: true,
  ),
];
