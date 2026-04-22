import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const FlutterLogo(size: 72),
            const SizedBox(height: 16),
            Text(
              'Real Estate App',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed(RouteNames.home);
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
