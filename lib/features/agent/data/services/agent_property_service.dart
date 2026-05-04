import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ListingTeamOption {
  const ListingTeamOption({required this.id, required this.name});

  factory ListingTeamOption.fromJson(Map<String, dynamic> json) {
    return ListingTeamOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Agent Team',
    );
  }

  final String id;
  final String name;
}

class OptimizedPropertyImages {
  const OptimizedPropertyImages({
    required this.detailBytes,
    required this.thumbnailBytes,
  });

  final Uint8List detailBytes;
  final Uint8List thumbnailBytes;
}

class UploadedPropertyImage {
  const UploadedPropertyImage({
    required this.publicUrl,
    required this.thumbnailPublicUrl,
  });

  final String publicUrl;
  final String thumbnailPublicUrl;
}

class AgentPropertyService {
  const AgentPropertyService._();

  static SupabaseClient get _client => Supabase.instance.client;

  static Future<List<ListingTeamOption>> fetchListingTeamOptions() async {
    final List<dynamic> rows = await _client
        .from('agent_teams')
        .select('id, name')
        .order('name');

    return rows
        .map(
          (row) =>
              ListingTeamOption.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  static Future<OptimizedPropertyImages> optimizePropertyImages(
    Uint8List bytes,
  ) async {
    final Uint8List detailBytes = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: 1600,
      minHeight: 1200,
      quality: 72,
      format: CompressFormat.jpeg,
      autoCorrectionAngle: true,
    );

    final Uint8List thumbnailBytes =
        await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 560,
          minHeight: 420,
          quality: 64,
          format: CompressFormat.jpeg,
          autoCorrectionAngle: true,
        );

    if (detailBytes.isEmpty || thumbnailBytes.isEmpty) {
      throw const FormatException('Unsupported image format.');
    }

    return OptimizedPropertyImages(
      detailBytes: detailBytes,
      thumbnailBytes: thumbnailBytes,
    );
  }

  static Future<UploadedPropertyImage> uploadPropertyImage({
    required Uint8List bytes,
    required String userId,
  }) async {
    final OptimizedPropertyImages optimizedImages =
        await optimizePropertyImages(bytes);
    final int uploadTimestamp = DateTime.now().millisecondsSinceEpoch;
    final String detailFilePath = '$userId/$uploadTimestamp-detail.jpg';
    final String thumbnailFilePath = '$userId/$uploadTimestamp-thumb.jpg';

    await _client.storage
        .from('property-images')
        .uploadBinary(
          detailFilePath,
          optimizedImages.detailBytes,
          fileOptions: const FileOptions(
            cacheControl: '604800',
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    await _client.storage
        .from('property-images')
        .uploadBinary(
          thumbnailFilePath,
          optimizedImages.thumbnailBytes,
          fileOptions: const FileOptions(
            cacheControl: '604800',
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final String publicUrl = _client.storage
        .from('property-images')
        .getPublicUrl(detailFilePath);
    final String thumbnailPublicUrl = _client.storage
        .from('property-images')
        .getPublicUrl(thumbnailFilePath);

    return UploadedPropertyImage(
      publicUrl: publicUrl,
      thumbnailPublicUrl: thumbnailPublicUrl,
    );
  }
}
