import 'package:flutter/foundation.dart';

import '../../data/notification_model.dart';
import '../../domain/usecases/get_notifications_usecase.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController({this.getNotificationsUsecase});

  final GetNotificationsUsecase? getNotificationsUsecase;

  List<AppNotification> _notifications = <AppNotification>[];

  List<AppNotification> get notifications => _notifications;

  int get unreadCount {
    return _notifications.where((notification) => !notification.isRead).length;
  }

  Future<void> loadNotifications() async {
    _notifications =
        await getNotificationsUsecase?.call() ?? <AppNotification>[];
    notifyListeners();
  }
}
