abstract interface class NotificationsRepository {
  Future<List<String>> getNotifications();

  Future<void> markNotificationRead(String notificationId);
}
