class NotificationsLocalDatasource {
  final Set<String> _readIds = <String>{};

  Future<void> markRead(String notificationId) async {
    _readIds.add(notificationId);
  }

  Future<bool> isRead(String notificationId) async {
    return _readIds.contains(notificationId);
  }
}
