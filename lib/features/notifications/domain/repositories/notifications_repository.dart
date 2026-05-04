import '../../data/notification_model.dart';

abstract interface class NotificationsRepository {
  Future<List<AppNotification>> getNotifications();

  Future<void> markNotificationRead(String notificationId);

  Future<void> markAllNotificationsRead();
}
