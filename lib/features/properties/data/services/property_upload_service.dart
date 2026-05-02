import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class PropertyUploadService {
  PropertyUploadService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String _bucketName = 'property-images';

  Future<String> uploadImage(Uint8List bytes, String fileName) async {
    final safeFileName = fileName.replaceAll(RegExp(r'\s+'), '_');

    final storagePath =
        'properties/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    await _supabase.storage
        .from(_bucketName)
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    return _supabase.storage.from(_bucketName).getPublicUrl(storagePath);
  }
}
