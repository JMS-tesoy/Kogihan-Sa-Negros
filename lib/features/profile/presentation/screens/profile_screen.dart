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
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Profile'),
        centerTitle: true,
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            onPressed: _controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
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
          final String name = profile?.name.trim() ?? '';
          final String email = profile?.email.trim() ?? '';
          final String phone = profile?.phone.trim() ?? '';
          final int completedFields = <String>[
            name,
            email,
            phone,
          ].where((value) => value.isNotEmpty).length;
          final double completion = completedFields / 3;
          final bool isComplete = completedFields == 3;
          final Color progressColor = isComplete ? Colors.green : cs.primary;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              _ProfileHero(
                profile: profile,
                completion: completion,
                onEdit: () => _openEditProfile(context),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(Icons.verified_user_outlined, color: cs.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Profile Strength',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${(completion * 100).round()}%',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: progressColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: completion,
                          color: progressColor,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isComplete
                            ? 'Your contact profile is complete.'
                            : 'Add missing details so clients can reach you.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Contact Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _ProfileInfoTile(
                icon: Icons.badge_outlined,
                label: 'Full Name',
                value: name.isEmpty ? 'No name set' : name,
                isMissing: name.isEmpty,
              ),
              const SizedBox(height: 8),
              _ProfileInfoTile(
                icon: Icons.mail_outline_rounded,
                label: 'Email',
                value: email.isEmpty ? 'No email set' : email,
                isMissing: email.isEmpty,
              ),
              const SizedBox(height: 8),
              _ProfileInfoTile(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: phone.isEmpty ? 'No phone set' : phone,
                isMissing: phone.isEmpty,
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context) async {
    await Navigator.of(context).pushNamed(RouteNames.editProfile);
    if (!mounted) return;
    _controller.load();
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.completion,
    required this.onEdit,
  });

  final ProfileEntity? profile;
  final double completion;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String name = profile?.name.trim() ?? '';
    final String email = profile?.email.trim() ?? '';
    final bool isComplete = completion >= 1;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            Stack(
              alignment: Alignment.bottomRight,
              children: <Widget>[
                ProfileAvatar(imageUrl: profile?.avatarUrl ?? '', radius: 54),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: cs.surface, width: 3),
                  ),
                  child: Icon(
                    isComplete
                        ? Icons.verified_rounded
                        : Icons.priority_high_rounded,
                    color: cs.onPrimary,
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              name.isEmpty ? 'No name set' : name,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              email.isEmpty ? 'No email set' : email,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: FilledButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.isMissing,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isMissing;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isMissing ? cs.errorContainer : cs.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: isMissing ? cs.onErrorContainer : cs.onSecondaryContainer,
          ),
        ),
        title: Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        subtitle: Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: isMissing ? cs.error : cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        trailing: Icon(
          isMissing ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
          color: isMissing ? cs.error : cs.primary,
        ),
      ),
    );
  }
}
