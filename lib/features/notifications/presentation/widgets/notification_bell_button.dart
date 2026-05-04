import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../data/datasources/notifications_remote_datasource.dart';

class NotificationBellButton extends StatefulWidget {
  const NotificationBellButton({super.key});

  @override
  State<NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<NotificationBellButton> {
  final NotificationsRemoteDatasource _datasource =
      NotificationsRemoteDatasource();

  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final notifications = await _datasource.getNotifications();

    if (!mounted) return;

    setState(() {
      _unreadCount =
          notifications.where((notification) => !notification.isRead).length;
    });
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).pushNamed(RouteNames.notifications);

    if (!mounted) return;

    await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        IconButton(
          tooltip: 'Notifications',
          onPressed: _openNotifications,
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        if (_unreadCount > 0)
          Positioned(
            top: 5,
            right: 5,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 17,
                  minHeight: 17,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: theme.scaffoldBackgroundColor,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}