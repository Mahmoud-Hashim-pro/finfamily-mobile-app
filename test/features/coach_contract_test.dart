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
    testWidgets('1. status: success displays normal bot reply', (tester) async {
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

    testWidgets('2. status: refusal displays gentle safety redirect message with shield icon', (tester) async {
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

    testWidgets('3. status: emergency_disabled displays maintenance notice bubble', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'emergency_disabled',
          'reply': 'خدمة المساعد الذكي معطلة مؤقتاً للصيانة والتحديث.',
          'request_id': 'req-child-emergency',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال طوارئ');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تنويه هام 📢'), findsOneWidget);
      expect(find.text('خدمة المساعد الذكي معطلة مؤقتاً للصيانة والتحديث.'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });

    testWidgets('4. status: quota_exceeded displays daily quota notice bubble', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'quota_exceeded',
          'reply': 'لقد استهلكت حد الأسئلة اليومي، نراك غداً يا بطل!',
          'request_id': 'req-child-quota',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال كوتا');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تنبيه: استهلاك الرصيد ⏳'), findsOneWidget);
      expect(find.text('لقد استهلكت حد الأسئلة اليومي، نراك غداً يا بطل!'), findsOneWidget);
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });

    testWidgets('5. status: spend_ceiling_exceeded displays monthly budget ceiling notice bubble', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'spend_ceiling_exceeded',
          'reply': 'تم الوصول إلى سقف الميزانية الشهري المخصص للذكاء الاصطناعي. يرجى مراجعة ولي الأمر أو مسؤول العائلة.',
          'request_id': 'req-child-spend-ceiling',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال ميزانية');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تنبيه: سقف الميزانية الشهري 💰'), findsOneWidget);
      expect(find.text('تم الوصول إلى سقف الميزانية الشهري المخصص للذكاء الاصطناعي. يرجى مراجعة ولي الأمر أو مسؤول العائلة.'), findsOneWidget);
      expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
      expect(find.text('معرّف الطلب: req-child-spend-ceiling'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });

    testWidgets('6. status: rate_limited displays error bubble with Retry action button', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'rate_limited',
          'reply': 'تم تجاوز حد المحاولات المسموح بها مؤقتاً.',
          'request_id': 'req-child-rate-limit',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال متكرر');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('مهلاً يا بطل! تم تجاوز حد الطلبات ⏳'), findsOneWidget);
      expect(find.text('تم تجاوز حد المحاولات المسموح بها مؤقتاً.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('7. status: timeout displays timeout error bubble with Retry action button', (tester) async {
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

    testWidgets('8. status: fallback displays safe fallback reply without error styling', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'fallback',
          'reply': 'أهلاً بك يا بطل! 🤖 كيف يمكنني مساعدتك اليوم في توفير أموالك وتحقيق أهدافك؟',
          'request_id': 'req-child-fallback',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال عادي');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('أهلاً بك يا بطل! 🤖 كيف يمكنني مساعدتك اليوم في توفير أموالك وتحقيق أهدافك؟'), findsOneWidget);
      expect(find.text('معرّف الطلب: req-child-fallback'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });

    testWidgets('9. status: error displays general error bubble with Retry action button', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'error',
          'reply': 'حدث خطأ في معالجة طلبك، يرجى المحاولة لاحقاً.',
          'request_id': 'req-child-error',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'سؤال به خطأ');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تعذر الاتصال ⚠️'), findsOneWidget);
      expect(find.text('حدث خطأ في معالجة طلبك، يرجى المحاولة لاحقاً.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('Retry Action Interaction: resubmits exact prompt, updates error state, and avoids duplicating user bubble or polluting history', (tester) async {
      int callCount = 0;
      final fake = _FakeAdapter((options) {
        callCount++;
        final data = options.data is Map ? options.data as Map : {};
        final message = data['message'];

        if (message == 'سؤال يحتاج إعادة المحاولة') {
          if (callCount == 1) {
            return _json(200, {
              'status': 'rate_limited',
              'reply': 'تم تجاوز حد الطلبات مؤقتاً.',
              'request_id': 'req-child-retry-1',
            });
          }
          return _json(200, {
            'status': 'success',
            'reply': 'تم الرد بنجاح بعد إعادة المحاولة! 🎉',
            'request_id': 'req-child-retry-2',
          });
        }

        // Follow-up question
        return _json(200, {
          'status': 'success',
          'reply': 'رد على سؤال المتابعة 🌟',
          'request_id': 'req-child-followup',
        });
      });
      ApiClient().dio.httpClientAdapter = fake;

      await tester.pumpWidget(const MaterialApp(home: ChildCoachScreen()));
      await _settle(tester);

      // Step 1: User sends message -> fails with rate_limited
      await tester.enterText(find.byType(TextField), 'سؤال يحتاج إعادة المحاولة');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      // Assert error bubble shown with retry button
      expect(find.text('مهلاً يا بطل! تم تجاوز حد الطلبات ⏳'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      // Assert user message is rendered exactly ONCE in UI
      expect(find.text('سؤال يحتاج إعادة المحاولة'), findsOneWidget);

      // Step 2: Tap "إعادة المحاولة"
      await tester.tap(find.text('إعادة المحاولة'));
      await _settle(tester);

      // Assert API re-called with exact prompt
      expect(fake.requests.length, 2);
      expect(fake.requests[0].data['message'], 'سؤال يحتاج إعادة المحاولة');
      expect(fake.requests[1].data['message'], 'سؤال يحتاج إعادة المحاولة');

      // Assert error state is replaced smoothly and bot reply is shown
      expect(find.text('تم الرد بنجاح بعد إعادة المحاولة! 🎉'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);

      // CRITICAL: Assert user question was NOT duplicated in chat UI
      expect(find.text('سؤال يحتاج إعادة المحاولة'), findsOneWidget);

      // Step 3: User sends follow-up question
      await tester.enterText(find.byType(TextField), 'سؤال متابعة');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('رد على سؤال المتابعة 🌟'), findsOneWidget);

      // Assert multi-turn history in 3rd request has:
      // - exact prior turns (user + assistant)
      // - NO duplicate user turns
      // - NO local notice or error bubbles
      expect(fake.requests.length, 3);
      final thirdHistory = fake.requests[2].data['history'] as List;
      expect(thirdHistory, isNotNull);

      final userHistoryTurns = thirdHistory.where((turn) => turn['role'] == 'user').toList();
      expect(userHistoryTurns.length, 1);
      expect(userHistoryTurns.first['content'], 'سؤال يحتاج إعادة المحاولة');

      final assistantHistoryTurns = thirdHistory.where((turn) => turn['role'] == 'assistant').toList();
      expect(assistantHistoryTurns.length, 1);
      expect(assistantHistoryTurns.first['content'], 'تم الرد بنجاح بعد إعادة المحاولة! 🎉');

      for (final turn in thirdHistory) {
        final content = turn['content'] as String;
        expect(content, isNot(contains('تم تجاوز حد الطلبات')));
        expect(content, isNot(contains('أهلاً يا بطل')));
      }
    });

    testWidgets('notice bubbles (emergency, quota, spend_ceiling) are NEVER sent in history payload', (tester) async {
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
            'status': 'quota_exceeded',
            'reply': 'تنبيه كوتا',
          });
        }
        if (msg == 'سؤال 3') {
          return _json(200, {
            'status': 'spend_ceiling_exceeded',
            'reply': 'تنبيه سقف الميزانية',
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

      // Q1 -> emergency_disabled
      await tester.enterText(find.byType(TextField), 'سؤال 1');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      // Q2 -> quota_exceeded
      await tester.enterText(find.byType(TextField), 'سؤال 2');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      // Q3 -> spend_ceiling_exceeded
      await tester.enterText(find.byType(TextField), 'سؤال 3');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      // Q4 -> success
      await tester.enterText(find.byType(TextField), 'سؤال 4');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      // Assert none of the notice messages are present in any history payload
      for (final req in fake.requests) {
        final data = req.data is Map ? req.data as Map : {};
        final history = data['history'] as List?;
        if (history != null) {
          for (final h in history) {
            final content = h['content'] as String?;
            expect(content, isNot(contains('تنبيه طوارئ')));
            expect(content, isNot(contains('تنبيه كوتا')));
            expect(content, isNot(contains('تنبيه سقف الميزانية')));
            expect(content, isNot(contains('أهلاً يا بطل')));
          }
        }
      }
    });
  });

  group('ParentCoachScreen contract tests', () {
    testWidgets('1. status: success displays normal assistant message', (tester) async {
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

    testWidgets('2. status: refusal displays gentle safety redirect message with shield icon', (tester) async {
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
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
    });

    testWidgets('3. status: emergency_disabled displays maintenance notice bubble', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'emergency_disabled',
          'reply': 'خدمة المستشار المالي معطلة مؤقتاً للصيانة والتحديث.',
          'request_id': 'req-parent-emergency',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ParentCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'استشارة صيانة');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تنويه هام 📢'), findsOneWidget);
      expect(find.text('خدمة المستشار المالي معطلة مؤقتاً للصيانة والتحديث.'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });

    testWidgets('4. status: quota_exceeded displays informative quota notice bubble', (tester) async {
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
      expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });

    testWidgets('5. status: spend_ceiling_exceeded displays monthly budget ceiling notice bubble', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'spend_ceiling_exceeded',
          'reply': 'تم استهلاك سقف الميزانية الشهري المخصص للذكاء الاصطناعي. يُرجى مراجعة مسؤول العائلة.',
          'request_id': 'req-parent-spend-ceiling',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ParentCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'استشارة سقف الميزانية');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تنبيه: سقف الميزانية الشهري 💰'), findsOneWidget);
      expect(find.text('تم استهلاك سقف الميزانية الشهري المخصص للذكاء الاصطناعي. يُرجى مراجعة مسؤول العائلة.'), findsOneWidget);
      expect(find.byIcon(Icons.savings_outlined), findsOneWidget);
      expect(find.text('معرّف الطلب: req-parent-spend-ceiling'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });

    testWidgets('6. status: rate_limited displays error bubble with Retry and resubmits', (tester) async {
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

    testWidgets('7. status: timeout displays error bubble with Retry action button', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'timeout',
          'reply': 'انتهت مهلة انتظار خادم الذكاء الاصطناعي.',
          'request_id': 'req-parent-timeout',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ParentCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'استشارة بطيئة');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('انتهت مهلة الانتظار ⏱️'), findsOneWidget);
      expect(find.text('انتهت مهلة انتظار خادم الذكاء الاصطناعي.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('8. status: fallback displays assistant reply smoothly without error styling', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'fallback',
          'reply': 'عذراً، يواجه المستشار المالي صعوبة مؤقتة في الاتصال. يرجى المحاولة بعد قليل.',
          'request_id': 'req-parent-fallback',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ParentCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'استشارة عادية');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('عذراً، يواجه المستشار المالي صعوبة مؤقتة في الاتصال. يرجى المحاولة بعد قليل.'), findsOneWidget);
      expect(find.text('معرّف الطلب: req-parent-fallback'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);
    });

    testWidgets('9. status: error displays error bubble with Retry action button', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {
          'status': 'error',
          'reply': 'حدث خطأ في النظام أثناء معالجة الطلب.',
          'request_id': 'req-parent-error',
        });
      });

      await tester.pumpWidget(const MaterialApp(home: ParentCoachScreen()));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'استشارة بها خطأ');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تعذر الاتصال ⚠️'), findsOneWidget);
      expect(find.text('حدث خطأ في النظام أثناء معالجة الطلب.'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
    });

    testWidgets('Retry Action Interaction in ParentCoachScreen: resubmits exact prompt, avoids duplicate user bubbles, and keeps history clean', (tester) async {
      int count = 0;
      final fake = _FakeAdapter((options) {
        count++;
        final data = options.data is Map ? options.data as Map : {};
        final message = data['message'];

        if (message == 'استشارة مالية للتقييم') {
          if (count == 1) {
            return _json(200, {
              'status': 'error',
              'reply': 'تعذر الاتصال بالخادم مؤقتاً.',
              'request_id': 'req-parent-retry-err',
            });
          }
          return _json(200, {
            'status': 'success',
            'reply': 'تم تحليل الميزانية العائلية بنجاح 📊',
            'request_id': 'req-parent-retry-ok',
          });
        }

        return _json(200, {
          'status': 'success',
          'reply': 'رد على الاستشارة الثانية 💼',
          'request_id': 'req-parent-followup',
        });
      });
      ApiClient().dio.httpClientAdapter = fake;

      await tester.pumpWidget(const MaterialApp(home: ParentCoachScreen()));
      await _settle(tester);

      // Send 1st question -> fails
      await tester.enterText(find.byType(TextField), 'استشارة مالية للتقييم');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('تعذر الاتصال ⚠️'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(find.text('استشارة مالية للتقييم'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.text('إعادة المحاولة'));
      await _settle(tester);

      // Assert re-submitted with exact prompt
      expect(fake.requests.length, 2);
      expect(fake.requests[0].data['message'], 'استشارة مالية للتقييم');
      expect(fake.requests[1].data['message'], 'استشارة مالية للتقييم');

      // Assert reply shown and retry gone
      expect(find.text('تم تحليل الميزانية العائلية بنجاح 📊'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsNothing);

      // CRITICAL: user question is NOT duplicated in UI
      expect(find.text('استشارة مالية للتقييم'), findsOneWidget);

      // Send follow-up question
      await tester.enterText(find.byType(TextField), 'استشارة لاحقة');
      await tester.tap(find.byIcon(Icons.send));
      await _settle(tester);

      expect(find.text('رد على الاستشارة الثانية 💼'), findsOneWidget);

      // Check history in 3rd request
      expect(fake.requests.length, 3);
      final thirdHistory = fake.requests[2].data['history'] as List;
      expect(thirdHistory, isNotNull);

      final userTurns = thirdHistory.where((t) => t['role'] == 'user').toList();
      expect(userTurns.length, 1);
      expect(userTurns.first['content'], 'استشارة مالية للتقييم');

      final assistantTurns = thirdHistory.where((t) => t['role'] == 'assistant').toList();
      expect(assistantTurns.length, 1);
      expect(assistantTurns.first['content'], 'تم تحليل الميزانية العائلية بنجاح 📊');

      for (final turn in thirdHistory) {
        final content = turn['content'] as String;
        expect(content, isNot(contains('تعذر الاتصال بالخادم')));
        expect(content, isNot(contains('أهلاً بك! أنا مستشارك')));
      }
    });
  });

  group('buildCoachHistory & buildParentCoachHistory unit tests', () {
    test('buildCoachHistory ignores local bubbles and converts bot role to assistant', () {
      final messages = [
        {'role': 'bot', 'text': 'ترحيب محلي', 'local': 'true', 'status': 'success'},
        {'role': 'user', 'text': 'سؤال 1'},
        {'role': 'bot', 'text': 'خطأ محلي', 'local': 'true', 'status': 'error'},
        {'role': 'bot', 'text': 'رد بوت سليم', 'status': 'success'},
        {'role': 'bot', 'text': 'تنبيه سقف الميزانية', 'local': 'true', 'status': 'spend_ceiling_exceeded'},
      ];

      final history = buildCoachHistory(messages);
      expect(history.length, 2);
      expect(history[0], {'role': 'user', 'content': 'سؤال 1'});
      expect(history[1], {'role': 'assistant', 'content': 'رد بوت سليم'});
    });

    test('buildParentCoachHistory ignores local bubbles and preserves assistant role', () {
      final messages = [
        {'role': 'assistant', 'text': 'ترحيب مستشار محلي', 'local': 'true', 'status': 'success'},
        {'role': 'user', 'text': 'استشارة 1'},
        {'role': 'assistant', 'text': 'خطأ محلي', 'local': 'true', 'status': 'rate_limited'},
        {'role': 'assistant', 'text': 'رد مستشار سليم', 'status': 'success'},
        {'role': 'assistant', 'text': 'تنبيه سقف الميزانية', 'local': 'true', 'status': 'spend_ceiling_exceeded'},
      ];

      final history = buildParentCoachHistory(messages);
      expect(history.length, 2);
      expect(history[0], {'role': 'user', 'content': 'استشارة 1'});
      expect(history[1], {'role': 'assistant', 'content': 'رد مستشار سليم'});
    });
  });
}
