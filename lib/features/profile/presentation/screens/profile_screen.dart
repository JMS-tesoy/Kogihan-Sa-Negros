import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../../../core/widgets/app_scaffold_shell.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/profile_menu_section.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffoldShell(
      title: 'Profile',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Center(child: ProfileAvatar()),
          const SizedBox(height: 24),
          ProfileMenuSection(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit profile'),
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.editProfile),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
