import 'package:dio/dio.dart';

class ApiErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'انتهت مهلة الاتصال بالخادم، يرجى التحقق من اتصال الإنترنت';
      }

      if (error.type == DioExceptionType.connectionError) {
        return 'تعذر الاتصال بالخادم، تأكد من اتصال الإنترنت وحاول ثانية';
      }

      final response = error.response;
      if (response != null && response.data != null) {
        final data = response.data;

        // FastAPI standard error format: {"detail": "..."}
        if (data is Map && data.containsKey('detail')) {
          final detail = data['detail'];

          if (detail is String) {
            return _translateDetail(detail);
          } else if (detail is List) {
            // FastAPI validation errors (422 Unprocessable Entity)
            final messages = detail.map((item) {
              if (item is Map && item.containsKey('msg')) {
                final loc = item['loc'];
                final field = loc is List && loc.isNotEmpty ? loc.last : '';
                return field.isNotEmpty ? '$field: ${item['msg']}' : item['msg'];
              }
              return item.toString();
            }).toList();
            return messages.join('\n');
          }
        }

        if (response.statusCode == 429) {
          return 'تم تجاوز الحد المسموح من المحاولات، يرجى الانتظار قليلاً';
        } else if (response.statusCode == 401) {
          return 'انتهت جلستك أو كلمة المرور غير صحيحة';
        } else if (response.statusCode == 403) {
          return 'ليس لديك صلاحية للوصول إلى هذا المحتوى';
        } else if (response.statusCode == 404) {
          return 'العنصر المطلوب غير موجود';
        } else if (response.statusCode == 500) {
          return 'حدث خطأ في الخادم الداخلي، يرجى المحاولة لاحقاً';
        }
      }
    }

    return error.toString().replaceAll('Exception:', '').trim();
  }

  static String _translateDetail(String detail) {
    switch (detail.toLowerCase()) {
      case 'not authenticated':
        return 'يرجى تسجيل الدخول أولاً';
      case 'invalid credentials':
      case 'incorrect email or password':
      case 'invalid email or password':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'email already registered':
        return 'هذا البريد الإلكتروني مسجل بالفعل';
      case 'invalid pin':
        return 'رمز الـ PIN غير صحيح';
      case 'family not found':
      case 'invalid family code':
        return 'كود العائلة غير صحيح أو غير موجود';
      case 'card is frozen':
        return 'هذا الكارت مجمد حالياً';
      case 'card is deactivated':
        return 'هذا الكارت ملغى';
      case 'insufficient balance':
        return 'الرصيد غير كافٍ لإتمام العملية';
      case 'spending limit exceeded':
        return 'تم تجاوز حد الصرف المسموح به';
      case 'mfa code invalid':
        return 'رمز التحقق الثنائي (2FA) غير صحيح';
      default:
        return detail;
    }
  }
}
