import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/core/api_client.dart';
import 'package:finfamily_mobile/features/child/child_coach_screen.dart';
import 'package:finfamily_mobile/features/parent/parent_coach_screen.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late HttpClientAdapter originalAdapter;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{'auth_token': 'test_token'});
    originalAdapter = ApiClient().dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient().dio.httpClientAdapter = originalAdapter;
  });

  group('ChildCoachScreen contract tests', () {
    testWidgets('status: success displays normal bot reply', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'success',
          'reply': 'ممتاز يا بطل! التوفير خطوة رائعة 💰',
          'request_id': 'req-child-success',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'إزاي أحوش؟');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('ممتاز يا بطل! التوفير خطوة رائعة 💰'), findsOneWidget);
      expect(find.text('معرّف الطلب: req-child-success'), findsOneWidget);
    });

    testWidgets('status: refusal displays gentle safety redirect message', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'refusal',
          'reply': 'أنا أساعدك فقط في الأمور المالية الإيجابية يا بطل! 🛡️',
          'request_id': 'req-child-refusal',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال غير مناسب');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('توجيه أمان ذكي 🛡️'), findsOneWidget);
      expect(find.text('أنا أساعدك فقط في الأمور المالية الإيجابية يا بطل! 🛡️'), findsOneWidget);
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('status: emergency_disabled and quota_exceeded display informative notice bubble', (tester) async {
      int requestCount = 0;
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        requestCount++;
        if (requestCount == 1) {
          return _json(200, {
            'status': 'emergency_disabled',
            'reply': 'خدمة المساعد الذكي معطلة مؤقتاً للصيانة.',
            'request_id': 'req-child-emergency',
          });
        }
        return _json(200, {
          'status': 'quota_exceeded',
          'reply': 'لقد استهلكت حد الأسئلة اليومي، نراك غداً!',
          'request_id': 'req-child-quota',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      // Send 1st question -> emergency_disabled
      await tester.enterText(find.byType(TextField), 'سؤال 1');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تنويه هام 📢'), findsOneWidget);
      expect(find.text('خدمة المساعد الذكي معطلة مؤقتاً للصيانة.'), findsOneWidget);

      // Send 2nd question -> quota_exceeded
      await tester.enterText(find.byType(TextField), 'سؤال 2');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تنبيه: استهلاك الرصيد ⏳'), findsOneWidget);
      expect(find.text('لقد استهلكت حد الأسئلة اليومي، نراك غداً!'), findsOneWidget);
    });

    testWidgets('status: rate_limited displays error bubble with Retry action button and allows resubmission', (tester) async {
      int attempt = 0;
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        attempt++;
        if (attempt == 1) {
          return _json(200, {
            'status': 'rate_limited',
            'reply': 'تم تجاوز حد المحاولات المسموح بها مؤقتاً.',
            'request_id': 'req-child-rate-limit',
          });
        }
        return _json(200, {
          'status': 'success',
          'reply': 'نجحت المحاولة بعد إعادة الإرسال! 🎉',
          'request_id': 'req-child-retry-success',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال للتجربة');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      // Error bubble is shown with "إعادة المحاولة" button
      expect(find.text('مهلاً يا بطل! تم تجاوز حد الطلبات ⏳'), findsOneWidget);
      expect(find.text('تم تجاوز حد المحاولات المسموح بها مؤقتاً.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      // Tap retry
      await tester.tap(find.text('إعادة المحاولة'));
      await _settle(tester);

      // Succeeded on retry
      expect(find.text('نجحت المحاولة بعد إعادة الإرسال! 🎉'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });

    testWidgets('status: timeout displays error bubble with Retry action button', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'timeout',
          'reply': 'استغرق المساعد وقتاً طويلاً للإجابة.',
          'request_id': 'req-child-timeout',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال بطيء');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('انتهت مهلة الانتظار ⏱️'), findsOneWidget);
      expect(find.text('استغرق المساعد وقتاً طويلاً للإجابة.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('notice bubbles and error bubbles are NEVER appended to history payload', (tester) async {
      final fake = _FakeAdapter((options) {
        final data = options.data is Map ? options.data as Map : {};
        final msg = data['message'];
        if (msg == 'سؤال 1') {
          return _json(200, {
            'status': 'emergency_disabled',
            'reply': 'تنبيه طوارئ',
          });
        }
        if (msg == 'سؤال 2') {
          return _json(200, {
            'status': 'rate_limited',
            'reply': 'حد الطلبات',
          });
        }
        return _json(200, {
          'status': 'success',
          'reply': 'رد عادي',
        });
      });
      ApiClient().dio.httpClientAdapter = fake;

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      // Q1 -> emergency_disabled (notice bubble marked local)
      await tester.enterText(find.byType(TextField), 'سؤال 1');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      // Q2 -> rate_limited (error bubble marked local)
      await tester.enterText(find.byType(TextField), 'سؤال 2');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      // Q3 -> success
      await tester.enterText(find.byType(TextField), 'سؤال 3');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      // Verify that in all requests recorded by the adapter, no history item has 'تنبيه طوارئ' or 'حد الطلبات'
      for (final req in fake.requests) {
        final data = req.data is Map ? req.data as Map : {};
        final history = data['history'] as List?;
        if (history != null) {
          for (final h in history) {
            final content = h['content'] as String?;
            expect(content, isNot(contains('تنبيه طوارئ')));
            expect(content, isNot(contains('حد الطلبات')));
            expect(content, isNot(contains('أهلاً يا بطل')));
          }
        }
      }
    });
  });

  group('ParentCoachScreen contract tests', () {
    testWidgets('status: success displays normal assistant message', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'success',
          'reply': 'إليك أفضل الطرق لتحديد المصروف للأبناء 💡',
          'request_id': 'req-parent-success',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ParentCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'كيف أحدد المصروف؟');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('إليك أفضل الطرق لتحديد المصروف للأبناء 💡'), findsOneWidget);
      expect(find.text('معرّف الطلب: req-parent-success'), findsOneWidget);
    });

    testWidgets('status: refusal displays gentle safety redirect message', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'refusal',
          'reply': 'أنا مستشارك المالي المخصص لتوجيه العائلة مالياً فقط.',
          'request_id': 'req-parent-refusal',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ParentCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'استشارة خارج النطاق');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('توجيه المستشار المالي 🛡️'), findsOneWidget);
      expect(find.text('أنا مستشارك المالي المخصص لتوجيه العائلة مالياً فقط.'), findsOneWidget);
    });

    testWidgets('status: quota_exceeded displays informative notice bubble', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'quota_exceeded',
          'reply': 'تم الوصول إلى الحد اليومي لاستخدام المستشار المالي.',
          'request_id': 'req-parent-quota',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ParentCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تنبيه: تم بلوغ الحد المسموح ⏳'), findsOneWidget);
      expect(find.text('تم الوصول إلى الحد اليومي لاستخدام المستشار المالي.'), findsOneWidget);
    });

    testWidgets('status: rate_limited displays error bubble with Retry and resubmits', (tester) async {
      int count = 0;
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        count++;
        if (count == 1) {
          return _json(200, {
            'status': 'rate_limited',
            'reply': 'يرجى الانتظار قليلاً قبل إرسال طلب جديد.',
            'request_id': 'req-parent-rate-limit',
          });
        }
        return _json(200, {
          'status': 'success',
          'reply': 'تمت الإجابة بنجاح بعد إعادة المحاولة.',
          'request_id': 'req-parent-success-after-retry',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ParentCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال للمستشار');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تم تجاوز حد الطلبات مؤقتاً ⏳'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.text('إعادة المحاولة'));
      await _settle(tester);

      expect(find.text('تمت الإجابة بنجاح بعد إعادة المحاولة.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });
  });
}
