import 'package:dio/dio.dart';
import '../config/api_config.dart';
import 'secure_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  Function()? onUnauthorized;

  ApiClient._internal() {
    // Configurable base URL support for environment flavors (--dart-define=API_BASE_URL=...)
    const envBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    String effectiveBaseUrl = envBaseUrl.isNotEmpty ? envBaseUrl : ApiConfig.baseUrl;

    // Transport security check (BUG-159): Enforce HTTPS for non-localhost endpoints
    final uri = Uri.tryParse(effectiveBaseUrl);
    if (uri != null && uri.host.isNotEmpty) {
      final isLocalhost = uri.host == 'localhost' ||
          uri.host == '127.0.0.1' ||
          uri.host == '10.0.2.2';
      if (!isLocalhost && uri.scheme == 'http') {
        effectiveBaseUrl = effectiveBaseUrl.replaceFirst('http://', 'https://');
      }
    }

    dio = Dio(
      BaseOptions(
        baseUrl: effectiveBaseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorageService().getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // BUG-085: Only clear session when the 401 is an actual token/session invalidation,
          // rather than an action-specific failure (e.g. wrong current password, invalid PIN, or MFA step)
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            final isAuthActionEndpoint = path.contains('/login') ||
                path.contains('/child-login') ||
                path.contains('/child/login') ||
                path.contains('/mfa/verify') ||
                path.contains('/change-password') ||
                path.contains('/reset-child-pin') ||
                path.contains('/verify-pin');

            final responseData = error.response?.data;
            final detail = (responseData is Map ? responseData['detail'] : '').toString().toLowerCase();

            // Operation-specific validation failures must not revoke the user's active session
            final isOperationalFailure = detail.contains('pin') ||
                detail.contains('password') ||
                detail.contains('mfa') ||
                detail.contains('recovery') ||
                detail.contains('too many attempts');

            if (!isAuthActionEndpoint && !isOperationalFailure) {
              await SecureStorageService().clearSession();
              if (onUnauthorized != null) {
                onUnauthorized!();
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.post(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> put(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.put(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> patch(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.patch(path, data: data, queryParameters: queryParameters);
  }

  Future<Response> delete(String path, {dynamic data, Map<String, dynamic>? queryParameters}) async {
    return await dio.delete(path, data: data, queryParameters: queryParameters);
  }
}
