import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_datasource.dart';
import '../notification_model.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  NotificationsRepositoryImpl({NotificationsRemoteDatasource? remoteDatasource})
    : _remoteDatasource = remoteDatasource ?? NotificationsRemoteDatasource();

  final NotificationsRemoteDatasource _remoteDatasource;

  @override
  Future<List<AppNotification>> getNotifications() {
    return _remoteDatasource.getNotifications();
  }

  @override
  Future<void> markNotificationRead(String notificationId) {
    return _remoteDatasource.markNotificationRead(notificationId);
  }

  @override
  Future<void> markAllNotificationsRead() {
    return _remoteDatasource.markAllNotificationsRead();
  }
}
