import 'package:flutter/material.dart';

import '../screens/subscription_screen.dart';

Future<void> openSubscriptionPage(BuildContext context) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const SubscriptionPage()),
  );
}
