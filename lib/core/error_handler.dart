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
                String field = '';
                if (loc is List && loc.isNotEmpty) {
                  // Filter out transport wrapper names ('body', 'query') and integer array indices (e.g. 0, 1)
                  final stringParts = loc
                      .where((p) => p is String && p != 'body' && p != 'query' && p != 'path')
                      .map((p) => p.toString())
                      .toList();
                  if (stringParts.isNotEmpty) {
                    field = stringParts.last;
                  }
                }
                final msg = _translateDetail(item['msg']?.toString() ?? 'خطأ في الإدخال');
                return field.isNotEmpty ? '$field: $msg' : msg;
              }
              return item.toString();
            }).toList();
            return messages.join('\n');
          }
        }

        if (response.statusCode == 429) {
          return 'تم تجاوز الحد المسموح من المحاولات، يرجى الانتظار قليلاً';
        } else if (response.statusCode == 401) {
          return 'انتهت جلستك أو كلمة المرور / رمز PIN غير صحيح';
        } else if (response.statusCode == 403) {
          return 'ليس لديك صلاحية للوصول إلى هذا المحتوى';
        } else if (response.statusCode == 404) {
          return 'العنصر المطلوب غير موجود أو غير مسجل';
        } else if (response.statusCode == 500) {
          return 'حدث خطأ في الخادم، يرجى المحاولة لاحقاً';
        }
      }
    }

    final raw = error.toString().replaceAll('Exception:', '').trim();
    return _translateDetail(raw);
  }

  static String _translateDetail(String detail) {
    final lower = detail.toLowerCase().trim();
    if (lower.contains('not authenticated')) return 'يرجى تسجيل الدخول أولاً';
    if (lower.contains('token expired') ||
        lower.contains('signature has expired') ||
        lower.contains('token has expired')) {
      return 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً';
    }
    if (lower.contains('invalid credentials') ||
        lower.contains('incorrect email or password') ||
        lower.contains('invalid email or password')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (lower.contains('email already registered')) return 'هذا البريد الإلكتروني مسجل بالفعل';
    if (lower.contains('admin email reserved')) return 'هذا البريد الإلكتروني مخصص لإدارة المنصة';
    if (lower.contains('invalid pin')) return 'رمز الـ PIN غير صحيح';
    if (lower.contains('family not found') || lower.contains('family code not found')) {
      return 'كود العائلة غير صحيح أو غير مسجل';
    }
    if (lower.contains('too many attempts')) {
      return 'تم حظر المحاولات مؤقتاً بسبب تكرار الخطأ، يرجى الانتظار والمحاولة لاحقاً';
    }
    if (lower.contains('mfa verification required') ||
        lower.contains('mfa code invalid') ||
        lower.contains('invalid authentication code')) {
      return 'رمز التحقق الثنائي (2FA) غير صحيح أو مطلوب';
    }
    if (lower.contains('invalid or already-used recovery code')) {
      return 'رمز الاسترداد غير صحيح أو تم استخدامه مسبقاً';
    }
    if (lower.contains('card is frozen')) return 'هذا الكارت مجمّد حالياً';
    if (lower.contains('card is deactivated')) return 'هذا الكارت ملغى نهائياً';
    if (lower.contains('insufficient balance') || lower.contains('not enough balance')) {
      return 'الرصيد المتاح غير كافٍ لإتمام العملية';
    }
    if (lower.contains('spending limit exceeded')) return 'تم تجاوز حد الصرف المسموح به';
    if (lower.contains('deposit exceeds goal target')) return 'المبلغ يتجاوز المبلغ المطلوب للهدف';
    if (lower.contains('reset link is invalid') || lower.contains('expired')) {
      return 'رابط أو رمز إعادة التعيين غير صالح أو منتهي الصلاحية';
    }
    if (lower.contains('field required')) return 'هذا الحقل مطلوب';
    if (lower.contains('10') && (lower.contains('apiexception') || lower.contains('sign_in_failed'))) {
      return 'تعذر إتمام الدخول عبر Google (كود 10): يلزم ربط بصمة التطبيق (SHA-1) بـ Google Console، أو يمكنك الدخول بالبريد وكلمة المرور مباشرة.';
    }
    if (lower.contains('sign_in_canceled') || lower.contains('sign_in_cancelled')) {
      return 'تم إلغاء عملية تسجيل الدخول عبر Google';
    }
    if (lower.contains('string should have at least')) return 'النص قصير جداً، يرجى إدخال المزيد من الأحرف';
    return detail;
  }
}
