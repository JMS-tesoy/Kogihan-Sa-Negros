import 'package:flutter/foundation.dart';

import '../../domain/usecases/get_notifications_usecase.dart';

class NotificationsController extends ChangeNotifier {
  NotificationsController({this.getNotificationsUsecase});

  final GetNotificationsUsecase? getNotificationsUsecase;

  List<String> _notifications = const <String>[];

  List<String> get notifications => _notifications;

  Future<void> load() async {
    _notifications = await getNotificationsUsecase?.call() ?? const <String>[];
    notifyListeners();
  }
}
