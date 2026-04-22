import 'api_result.dart';

class ApiClient {
  const ApiClient({this.baseUrl = ''});

  final String baseUrl;

  Future<ApiResult<Map<String, dynamic>>> get(String path) async {
    return ApiResult.success(<String, dynamic>{
      'path': path,
      'baseUrl': baseUrl,
    });
  }
}
