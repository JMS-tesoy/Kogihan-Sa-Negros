import '../repositories/notifications_repository.dart';

class MarkNotificationReadUsecase {
  const MarkNotificationReadUsecase(this.repository);

  final NotificationsRepository repository;

  Future<void> call(String notificationId) {
    return repository.markNotificationRead(notificationId);
  }
}
