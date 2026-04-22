import 'package:flutter/material.dart';

class AttachmentPreview extends StatelessWidget {
  const AttachmentPreview({
    super.key,
    required this.fileName,
  });

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.attach_file),
      label: Text(fileName),
    );
  }
}
