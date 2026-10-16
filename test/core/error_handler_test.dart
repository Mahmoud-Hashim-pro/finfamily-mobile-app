import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:finfamily_mobile/core/error_handler.dart';

void main() {
  group('ApiErrorHandler - FastAPI Validation Parsing', () {
    test('handles loc containing integer indices without crashing', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/test'),
          statusCode: 422,
          data: {
            'detail': [
              {
                'loc': ['body', 'items', 0, 'amount'],
                'msg': 'Field required',
                'type': 'value_error.missing',
              }
            ]
          },
        ),
      );

      final message = ApiErrorHandler.getErrorMessage(dioException);
      expect(message, contains('amount'));
      expect(message, isNot(contains('0:')));
    });

    test('handles standard string detail messages', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/test'),
          statusCode: 400,
          data: {'detail': 'Invalid credentials'},
        ),
      );

      final message = ApiErrorHandler.getErrorMessage(dioException);
      expect(message, equals('البريد الإلكتروني أو كلمة المرور غير صحيحة'));
    });

    test('translates token expiration messages', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/test'),
          statusCode: 401,
          data: {'detail': 'Signature has expired'},
        ),
      );

      final message = ApiErrorHandler.getErrorMessage(dioException);
      expect(message, equals('انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً'));
    });

    test('translates rate limiting 429 status code', () {
      final dioException = DioException(
        requestOptions: RequestOptions(path: '/api/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/api/test'),
          statusCode: 429,
          data: {},
        ),
      );

      final message = ApiErrorHandler.getErrorMessage(dioException);
      expect(message, contains('تم تجاوز الحد المسموح من المحاولات'));
    });

    test('translates Google Sign-In ApiException 10 developer error into actionable Arabic message', () {
      const err = 'PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)';
      final message = ApiErrorHandler.getErrorMessage(err);
      expect(message, contains('كود 10'));
      expect(message, contains('SHA-1'));
    });
  });
}
