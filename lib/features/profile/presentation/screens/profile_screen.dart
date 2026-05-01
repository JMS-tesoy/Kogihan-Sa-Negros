import 'package:flutter/material.dart';

import '../../../../app/router/route_names.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ProfileController _controller;

  @override
  void initState() {
    super.initState();
    final datasource = ProfileRemoteDatasource();
    final repository = ProfileRepositoryImpl(remoteDatasource: datasource);
    _controller = ProfileController(
      getProfileUsecase: GetProfileUsecase(repository),
      updateProfileUsecase: UpdateProfileUsecase(repository),
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _controller.error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _controller.load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final ProfileEntity? profile = _controller.profile;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: ProfileAvatar(
                  imageUrl: profile?.avatarUrl ?? '',
                  radius: 48,
                ),
              ),
              const SizedBox(height: 16),
              if (profile != null) ...[
                Center(
                  child: Text(
                    profile.name.isNotEmpty ? profile.name : 'No name set',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (profile.email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      profile.email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 32),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Edit Profile'),
                      subtitle: const Text('Update your name and phone'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(
                          context,
                        ).pushNamed(RouteNames.editProfile);
                        if (!mounted) return;
                        _controller.load();
                      },
                    ),
                    if (profile != null && profile.phone.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('Phone'),
                        subtitle: Text(profile.phone),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
