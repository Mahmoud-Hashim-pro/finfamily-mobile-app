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
      final statusCode = response?.statusCode;
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
      }

      // Status-code mapping also covers empty / plain-text bodies (e.g. Vercel 502/504 pages)
      if (statusCode != null) {
        if (statusCode == 429) {
          return 'تم تجاوز الحد المسموح من المحاولات، يرجى الانتظار قليلاً';
        } else if (statusCode == 401) {
          return 'انتهت جلستك أو كلمة المرور / رمز PIN غير صحيح';
        } else if (statusCode == 403) {
          return 'ليس لديك صلاحية للوصول إلى هذا المحتوى';
        } else if (statusCode == 404) {
          return 'العنصر المطلوب غير موجود أو غير مسجل';
        } else if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
          return 'الخادم مشغول حالياً أو استغرق وقتاً أطول من المتوقع، يرجى المحاولة بعد قليل';
        } else if (statusCode >= 500) {
          return 'حدث خطأ في الخادم، يرجى المحاولة لاحقاً';
        } else if (statusCode >= 400) {
          return 'تعذر إتمام الطلب، يرجى المحاولة مرة أخرى';
        }
      }

      // Never show the raw English DioException dump to users
      if (error.type == DioExceptionType.cancel) {
        return 'تم إلغاء الطلب';
      }
      if (error.type == DioExceptionType.badCertificate) {
        return 'تعذر التحقق من أمان الاتصال بالخادم';
      }
      return 'حدث خطأ غير متوقع أثناء الاتصال بالخادم، يرجى المحاولة مرة أخرى';
    }

    final raw = error.toString().replaceAll('Exception:', '').trim();
    return _translateDetail(raw);
  }

  static String _translateDetail(String detail) {
    final lower = detail.toLowerCase().trim();
    if (lower.contains('not authenticated')) return 'يرجى تسجيل الدخول أولاً';
    // MFA challenge (temp token) expired: the user must restart login, codes can't succeed anymore
    if (lower.contains('expired temporary session') ||
        lower.contains('expired temporary admin session') ||
        lower.contains('invalid mfa token') ||
        lower.contains('invalid admin mfa challenge token')) {
      return 'انتهت مهلة التحقق الثنائي، يرجى تسجيل الدخول مجدداً';
    }
    // C13: Google identity proof (Google-only parents). Checked before the session-expiry block
    // because the verifier text may read 'Invalid Google ID token: Google ID token has expired'.
    if (lower.contains('google authentication does not match') || lower.contains('identity mismatch')) {
      return 'حساب Google الذي اخترته لا يطابق حسابك في FinFamily، يرجى اختيار نفس الحساب';
    }
    if (lower.contains('google re-authentication is required')) {
      return 'يرجى تأكيد هويتك عبر Google للمتابعة';
    }
    if (lower.contains('invalid google') || lower.contains('google authentication failed')) {
      return 'تعذر التحقق من حساب Google، يرجى المحاولة مرة أخرى';
    }
    if (lower.contains('token expired') ||
        lower.contains('signature has expired') ||
        lower.contains('token has expired') ||
        lower.contains('invalid or expired token') ||
        lower.contains('expired admin session token') ||
        lower.contains('token has been revoked')) {
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
    if (lower.contains('too many attempts') || lower.contains('too many failed authentication code attempts')) {
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
    if (lower.contains('deposit exceeds savings goal target') ||
        lower.contains('deposit exceeds goal target')) {
      return 'المبلغ يتجاوز المبلغ المطلوب للهدف';
    }
    if (lower.contains('not enough savings')) return 'المبلغ المحوّش في الهدف غير كافٍ للسحب';
    if (lower.contains('reset link') || lower.contains('reset token')) {
      return 'رابط أو رمز إعادة التعيين غير صالح أو منتهي الصلاحية';
    }
    if (lower.contains('field required')) return 'هذا الحقل مطلوب';
    if (lower.contains('10') && (lower.contains('apiexception') || lower.contains('sign_in_failed'))) {
      return 'تعذر إتمام الدخول عبر Google (كود 10): يلزم ربط بصمة التطبيق (SHA-1) بـ Google Console، أو يمكنك الدخول بالبريد وكلمة المرور مباشرة.';
    }
    if (lower.contains('sign_in_canceled') || lower.contains('sign_in_cancelled')) {
      return 'تم إلغاء عملية تسجيل الدخول عبر Google';
    }
    if (lower.contains('only parent accounts can sign in via google login')) {
      return 'حسابات أولياء الأمور فقط هي المسموح لها بتسجيل الدخول عبر Google';
    }
    if (lower.contains('account not found') || lower.contains('غير مسجل بعد')) {
      return 'هذا الحساب غير مسجل بعد في FinFamily. يرجى إنشاء حساب جديد.';
    }
    if (lower.contains('string should have at least')) return 'النص قصير جداً، يرجى إدخال المزيد من الأحرف';
    if (lower.contains('string should have at most')) return 'النص طويل جداً، يرجى تقصير الرسالة';
    if (lower.contains('proof_url must be an http')) return 'رابط الإثبات لازم يكون رابط صحيح يبدأ بـ https://';
    return detail;
  }
}
