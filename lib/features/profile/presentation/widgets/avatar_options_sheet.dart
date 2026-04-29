import 'package:flutter/material.dart';

class AvatarOptionsSheet extends StatelessWidget {
  final bool canRemoveAvatar;
  final VoidCallback onChooseFromGallery;
  final VoidCallback onTakePhoto;
  final VoidCallback onRemoveAvatar;

  const AvatarOptionsSheet({
    super.key,
    required this.canRemoveAvatar,
    required this.onChooseFromGallery,
    required this.onTakePhoto,
    required this.onRemoveAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from Gallery'),
            onTap: () {
              Navigator.pop(context);
              onChooseFromGallery();
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Take a Photo'),
            onTap: () {
              Navigator.pop(context);
              onTakePhoto();
            },
          ),
          if (canRemoveAvatar)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Remove Avatar',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                onRemoveAvatar();
              },
            ),
        ],
      ),
    );
  }
}
