import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/supabase_config.dart';

class ProfileAvatarService {
  const ProfileAvatarService._();

  static Future<void> saveAvatarForCurrentUser(Uint8List imageBytes) async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in again before uploading your avatar.');
    }

    final String avatarPath =
        '${user.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';

    await Supabase.instance.client.storage
        .from(SupabaseConfig.profileAvatarsBucket)
        .uploadBinary(
          avatarPath,
          imageBytes,
          fileOptions: const FileOptions(
            cacheControl: '604800',
            upsert: true,
            contentType: 'image/jpeg',
          ),
        );

    final String avatarUrl = Supabase.instance.client.storage
        .from(SupabaseConfig.profileAvatarsBucket)
        .getPublicUrl(avatarPath);

    await Supabase.instance.client.from('profiles').upsert({
      'id': user.id,
      'avatar_url': avatarUrl,
    }, onConflict: 'id');
  }

  static Future<void> removeAvatarForCurrentUser() async {
    final User? user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    await Supabase.instance.client
        .from('profiles')
        .update({'avatar_url': null})
        .eq('id', user.id);
  }
}
