import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';

class ProfileRemoteDatasource {
  final SupabaseClient _client = Supabase.instance.client;

  Future<ProfileModel?> getProfile() async {
    final User? user = _client.auth.currentUser;
    if (user == null) return null;

    final Map<String, dynamic>? row = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (row == null) return null;

    return ProfileModel(
      id: row['id'] as String,
      name: (row['full_name'] as String?) ?? '',
      email: (row['email'] as String?) ?? '',
      phone: (row['phone'] as String?) ?? '',
      avatarUrl: (row['avatar_url'] as String?) ?? '',
    );
  }

  Future<void> updateProfile(ProfileModel profile) async {
    await _client.from('profiles').upsert({
      'id': profile.id,
      'full_name': profile.name.isEmpty ? null : profile.name,
      'email': profile.email.isEmpty ? null : profile.email,
      'phone': profile.phone.isEmpty ? null : profile.phone,
    }, onConflict: 'id');
  }
}
