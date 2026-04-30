import 'dart:typed_data';

class ProfileAvatarState {
  final Uint8List? imageBytes;
  final bool avatarHidden;
  final bool hasRemoteAvatar;

  const ProfileAvatarState({
    required this.imageBytes,
    required this.avatarHidden,
    required this.hasRemoteAvatar,
  });

  factory ProfileAvatarState.visible(Uint8List imageBytes) {
    return ProfileAvatarState(
      imageBytes: imageBytes,
      avatarHidden: false,
      hasRemoteAvatar: true,
    );
  }

  static const removed = ProfileAvatarState(
    imageBytes: null,
    avatarHidden: true,
    hasRemoteAvatar: false,
  );
}
