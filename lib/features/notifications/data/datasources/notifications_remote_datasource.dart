class NotificationsRemoteDatasource {
  Future<List<String>> getNotifications() async {
    return const <String>[];
  }

  Future<void> markNotificationRead(String notificationId) async {}
}
