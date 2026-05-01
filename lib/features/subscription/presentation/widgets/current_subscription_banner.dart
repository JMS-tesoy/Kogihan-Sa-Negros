import 'package:flutter/material.dart';

class CurrentSubscriptionBanner extends StatelessWidget {
  const CurrentSubscriptionBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      content: Text(message),
      actions: const <Widget>[SizedBox.shrink()],
    );
  }
}
