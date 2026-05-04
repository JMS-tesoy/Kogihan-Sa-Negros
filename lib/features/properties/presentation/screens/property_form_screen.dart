import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/services/property_upload_service.dart';

class PropertyFormScreen extends StatefulWidget {
  const PropertyFormScreen({super.key});

  @override
  State<PropertyFormScreen> createState() => _PropertyFormScreenState();
}

class _PropertyFormScreenState extends State<PropertyFormScreen> {
  final _titleController = TextEditingController();
  final _uploadService = PropertyUploadService();

  String? _uploadedUrl;
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;
    if (!mounted) return;

    setState(() => _isUploading = true);

    try {
      final bytes = await image.readAsBytes();
      final fileName = 'prop_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final uploadedUrl = await _uploadService.uploadImage(bytes, fileName);

      if (!mounted) return;

      setState(() {
        _uploadedUrl = uploadedUrl;
        _isUploading = false;
      });

      AppSnackBar.success(context, 'Property image uploaded successfully.');
    } catch (e) {
      if (!mounted) return;

      setState(() => _isUploading = false);

      AppSnackBar.error(context, 'Upload failed: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uploadedUrl = _uploadedUrl;

    return Scaffold(
      appBar: AppBar(title: const Text('Add New Land Listing')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Listing Title'),
            ),
            const SizedBox(height: 20),
            if (uploadedUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  uploadedUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 12),
              SelectableText(
                uploadedUrl,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
            ],
            if (_isUploading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _pickAndUpload,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                _isUploading ? 'Uploading...' : 'Upload Photo to Supabase',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
