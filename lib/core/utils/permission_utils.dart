enum PermissionRequestStatus { granted, denied, restricted }

abstract final class PermissionUtils {
  static bool isGranted(PermissionRequestStatus status) {
    return status == PermissionRequestStatus.granted;
  }
}
