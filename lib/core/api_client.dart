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

    // Transport security check (BUG-159 & FF-30): Fail-closed validation for effectiveBaseUrl
    final uri = Uri.tryParse(effectiveBaseUrl);
    if (uri == null || uri.host.isEmpty || (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw StateError(
        'Invalid API base URL: "$effectiveBaseUrl". effectiveBaseUrl must have a valid scheme (http/https) and non-empty host.',
      );
    }

    final isLocalhost = uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '10.0.2.2';
    if (!isLocalhost && uri.scheme == 'http') {
      effectiveBaseUrl = effectiveBaseUrl.replaceFirst('http://', 'https://');
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
                path.contains('/verify-pin') ||
                path.contains('/google');

            final responseData = error.response?.data;
            final detail = (responseData is Map ? responseData['detail'] : '').toString().toLowerCase();

            // Operation-specific validation failures must not revoke the user's active session.
            // C13: a Google-only parent confirming MFA settings / re-auth with the wrong Google
            // account gets a 401 'Google authentication does not match ...' / 'Invalid Google ...
            // re-authentication token' — that is a failed identity proof, not an expired session.
            final isOperationalFailure = detail.contains('pin') ||
                detail.contains('password') ||
                detail.contains('mfa') ||
                detail.contains('recovery') ||
                detail.contains('too many attempts') ||
                detail.contains('google') ||
                detail.contains('re-authentication');

            // A 401 for a request sent with a credential that is no longer current
            // (e.g. the user re-logged in while it was in flight) must not wipe the new session.
            final sentAuth = error.requestOptions.headers['Authorization']?.toString();
            final currentToken = await SecureStorageService().getToken();
            final currentAuth = (currentToken != null && currentToken.isNotEmpty) ? 'Bearer $currentToken' : null;
            final isStaleCredential = sentAuth != currentAuth;

            if (!isAuthActionEndpoint && !isOperationalFailure && !isStaleCredential) {
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
