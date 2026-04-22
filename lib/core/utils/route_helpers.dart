import 'package:flutter/widgets.dart';

abstract final class RouteHelpers {
  static void goTo(BuildContext context, String routeName) {
    Navigator.of(context).pushNamed(routeName);
  }

  static void replaceWith(BuildContext context, String routeName) {
    Navigator.of(context).pushReplacementNamed(routeName);
  }
}
