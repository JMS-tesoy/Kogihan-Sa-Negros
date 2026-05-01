import '../network/network_checker.dart';

class ConnectivityService {
  ConnectivityService({NetworkChecker? checker})
    : _checker = checker ?? const NetworkChecker();

  final NetworkChecker _checker;

  Future<bool> get isOnline => _checker.hasConnection;
}
