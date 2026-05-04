import '../../data/notification_model.dart';
import '../repositories/notifications_repository.dart';

class GetNotificationsUsecase {
  const GetNotificationsUsecase(this.repository);

  final NotificationsRepository repository;

  Future<List<AppNotification>> call() {
    return repository.getNotifications();
  }
}
