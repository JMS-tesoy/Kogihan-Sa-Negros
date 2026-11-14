import 'dart:io';

class NetworkChecker {
  const NetworkChecker();

  Future<bool> get hasConnection async {
    try {
      final result = await InternetAddress.lookup(
        'vludvvjkrrqzjahxjdjl.supabase.co',
      );

      return result.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}