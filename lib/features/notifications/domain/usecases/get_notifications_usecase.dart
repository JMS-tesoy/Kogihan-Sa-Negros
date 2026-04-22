import '../repositories/notifications_repository.dart';

class GetNotificationsUsecase {
  const GetNotificationsUsecase(this.repository);

  final NotificationsRepository repository;

  Future<List<String>> call() {
    return repository.getNotifications();
  }
}
