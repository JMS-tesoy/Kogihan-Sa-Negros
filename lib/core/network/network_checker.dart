import 'dart:io';

class NetworkChecker {
  const NetworkChecker();

  Future<bool> get hasConnection async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      return false;
    }
  }
}
