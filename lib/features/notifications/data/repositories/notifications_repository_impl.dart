import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_datasource.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({NotificationsRemoteDatasource? remoteDatasource})
      : _remoteDatasource = remoteDatasource ?? NotificationsRemoteDatasource();

  final NotificationsRemoteDatasource _remoteDatasource;

  @override
  Future<List<String>> getNotifications() {
    return _remoteDatasource.getNotifications();
  }

  @override
  Future<void> markNotificationRead(String notificationId) {
    return _remoteDatasource.markNotificationRead(notificationId);
  }
}
