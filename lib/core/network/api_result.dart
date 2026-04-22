class ApiResult<T> {
  const ApiResult._({
    this.data,
    this.message,
    required this.isSuccess,
  });

  final T? data;
  final String? message;
  final bool isSuccess;

  factory ApiResult.success(T data) {
    return ApiResult._(data: data, isSuccess: true);
  }

  factory ApiResult.failure(String message) {
    return ApiResult._(message: message, isSuccess: false);
  }
}
