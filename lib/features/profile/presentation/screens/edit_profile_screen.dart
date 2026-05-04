import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../data/services/avatar_picker_service.dart';
import '../../data/services/profile_avatar_service.dart';
import '../../domain/entities/profile_entity.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/update_profile_usecase.dart';
import '../controllers/profile_controller.dart';
import '../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final ProfileController _controller;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String _avatarUrl = '';
  Uint8List? _pickedAvatarBytes;
  bool _initialized = false;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final datasource = ProfileRemoteDatasource();
    final repository = ProfileRepositoryImpl(remoteDatasource: datasource);
    _controller = ProfileController(
      getProfileUsecase: GetProfileUsecase(repository),
      updateProfileUsecase: UpdateProfileUsecase(repository),
    );
    _controller.addListener(_onProfileLoaded);
    _controller.load();
  }

  void _onProfileLoaded() {
    if (_initialized) return;
    final ProfileEntity? profile = _controller.profile;
    if (profile == null) return;
    _nameController.text = profile.name;
    _phoneController.text = profile.phone;
    _avatarUrl = profile.avatarUrl;
    _initialized = true;
  }

  @override
  void dispose() {
    _controller.removeListener(_onProfileLoaded);
    _controller.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatarFromGallery() async {
    final Uint8List? imageBytes = await AvatarPickerService.pickGalleryAvatar();
    if (imageBytes == null) return;

    setState(() {
      _pickedAvatarBytes = imageBytes;
      _isUploadingAvatar = true;
    });

    try {
      final String avatarUrl =
          await ProfileAvatarService.saveAvatarForCurrentUser(imageBytes);

      if (!mounted) return;

      setState(() {
        _avatarUrl = avatarUrl;
        _isUploadingAvatar = false;
      });

      AppSnackBar.success(
        context,
        'Profile photo updated.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isUploadingAvatar = false);

      AppSnackBar.error(
        context,
        'Failed to update photo: $error',
      );
    }
  }

  Future<void> _save() async {
    final String name = _nameController.text.trim();

    if (name.isEmpty) {
      AppSnackBar.warning(
        context,
        'Name cannot be empty.',
      );
      return;
    }

    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final ProfileEntity updated = ProfileEntity(
      id: user.id,
      name: name,
      email: _controller.profile?.email ?? '',
      phone: _phoneController.text.trim(),
      avatarUrl: _avatarUrl,
    );

    final bool success = await _controller.update(updated);

    if (!mounted) return;

    if (success) {
      AppSnackBar.success(
        context,
        'Profile updated.',
      );

      Navigator.of(context).pop();
    } else {
      AppSnackBar.error(
        context,
        _controller.error ?? 'Failed to update profile.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile'), centerTitle: true),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoading && !_initialized) {
            return const Center(child: CircularProgressIndicator());
          }

          final String email = _controller.profile?.email ?? '';
          final String previewName = _nameController.text.trim();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: <Widget>[
                    _EditableAvatarPreview(
                      imageBytes: _pickedAvatarBytes,
                      imageUrl: _avatarUrl,
                      isUploading: _isUploadingAvatar,
                      onTap: _pickAvatarFromGallery,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      previewName.isEmpty ? 'Agent Name' : previewName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (email.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile Details',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Email',
                  helperText: 'Email is managed by your account login.',
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  email.isEmpty ? 'No email set' : email,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: email.isEmpty ? cs.error : cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_controller.isLoading) _save();
                },
                decoration: InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _controller.isLoading ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _controller.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Save Changes',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EditableAvatarPreview extends StatelessWidget {
  const _EditableAvatarPreview({
    required this.imageBytes,
    required this.imageUrl,
    required this.isUploading,
    required this.onTap,
  });

  final Uint8List? imageBytes;
  final String imageUrl;
  final bool isUploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: isUploading ? null : onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: <Widget>[
          if (imageBytes != null)
            CircleAvatar(
              radius: 50,
              backgroundColor: cs.primaryContainer,
              backgroundImage: MemoryImage(imageBytes!),
            )
          else
            ProfileAvatar(imageUrl: imageUrl, radius: 50),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
              border: Border.all(color: cs.surface, width: 3),
            ),
            child: isUploading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    ),
                  )
                : Icon(Icons.edit_outlined, size: 18, color: cs.onPrimary),
          ),
        ],
      ),
    );
  }
}