import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/config/api_config.dart';
import 'package:finfamily_mobile/core/api_client.dart';
import 'package:finfamily_mobile/features/parent/allowance_screen.dart';
import 'package:finfamily_mobile/features/parent/approvals_screen.dart';
import 'package:finfamily_mobile/features/parent/create_chore_dialog.dart';
import 'package:finfamily_mobile/features/parent/family_members_screen.dart';
import 'package:finfamily_mobile/features/parent/parent_coach_screen.dart';
import 'package:finfamily_mobile/features/parent/parent_dashboard_screen.dart';
import 'package:finfamily_mobile/features/parent/parent_mfa_settings_screen.dart';
import 'package:finfamily_mobile/features/parent/spending_limits_screen.dart';

ApprovalItem _item(ApprovalType type, {String kind = 'chore', double amount = 49.5, String id = '1'}) {
  return ApprovalItem(
    id: id,
    type: type,
    childId: 'child-1',
    childName: 'منى',
    title: 'عنوان',
    description: '',
    amount: amount,
    kind: kind,
  );
}

/// In-memory HTTP adapter: records every request and answers from [handler] (no network).
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

const _allReviewed = 'رائع! لا توجد طلبات معلقة';
const _sendAllowanceLabel = 'تحويل المصروف الآن 🚀';

const Map<String, Object> _submittedChore = {
  'id': 'm1',
  'child_id': 'c1',
  'child_name': 'منى',
  'title': 'ترتيب السرير',
  'reward': 15.0,
  'kind': 'chore',
  'status': 'submitted',
};

const Map<String, Object> _pendingPurchase = {
  'id': 'p1',
  'child_id': 'c1',
  'child_name': 'منى',
  'amount': 49.5,
  'merchant': 'Toy Shop',
  'category': 'Toys',
  'status': 'pending',
};

/// Dio's interceptor chain hops through zero-duration timers (`Future(() ...)`), which a plain
/// `pump()` never fires in the fake-async test zone: elapse zero time so the fake API calls complete,
/// then build their result.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump(Duration.zero);
  await tester.pump(Duration.zero);
}

/// Lets queued snackbars run out before the tree is torn down.
Future<void> _drainSnackBars(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Chore creation (#53 / #164 / #171)', () {
    test('chore category is one the backend MissionCreate validator accepts', () {
      expect(kDefaultChoreCategory, 'Home');
    });

    test('reward accepts Arabic-Indic digits and decimals', () {
      expect(parseChoreReward('٢٠'), 20.0);
      expect(parseChoreReward(' 15.5 '), 15.5);
      expect(parseChoreReward('٢٫٥'), 2.5);
      expect(parseChoreReward('abc'), isNull);
    });
  });

  group('Approvals presentation (#172 / #173 / #176)', () {
    test('chore payout is a credit, redemption is a debit, purchase is plain — with piastres', () {
      expect(approvalAmountLabel(_item(ApprovalType.mission)), '+49.50 ج.م');
      expect(approvalAmountLabel(_item(ApprovalType.mission, kind: 'redemption')), '-49.50 ج.م');
      expect(approvalAmountLabel(_item(ApprovalType.cardPurchase)), '49.50 ج.م');
    });

    test('redemptions are not presented as chores', () {
      final redemption = _item(ApprovalType.mission, kind: 'redemption');
      expect(redemption.isRedemption, isTrue);
      expect(redemption.isChore, isFalse);
      expect(approvalApproveLabel(redemption), 'موافقة وخصم من الرصيد');
      expect(approvalApproveLabel(_item(ApprovalType.mission)), 'موافقة وصرف');
      expect(approvalApproveLabel(_item(ApprovalType.cardPurchase)), 'موافقة على الشراء');
      expect(_item(ApprovalType.cardPurchase).isRedemption, isFalse);
    });

    test('in-flight keys separate missions and purchases that share an id', () {
      final mission = _item(ApprovalType.mission, id: 'abc');
      final purchase = _item(ApprovalType.cardPurchase, id: 'abc');
      expect(mission.actionKey, isNot(purchase.actionKey));
      expect(mission.actionKey, _item(ApprovalType.mission, id: 'abc').actionKey);
    });
  });

  group('Allowance idempotency (#169)', () {
    DioException dioWithStatus(int status) => DioException(
          requestOptions: RequestOptions(path: '/wallet/child/x/allowance'),
          response: Response(
            requestOptions: RequestOptions(path: '/wallet/child/x/allowance'),
            statusCode: status,
            data: {'detail': 'Idempotency key reused with conflicting request payload parameters'},
          ),
        );

    test('a 409 retires the retained key', () {
      expect(isIdempotencyKeyConsumed(dioWithStatus(409)), isTrue);
    });

    test('other failures keep the key for a safe retry', () {
      expect(isIdempotencyKeyConsumed(dioWithStatus(400)), isFalse);
      expect(isIdempotencyKeyConsumed(dioWithStatus(500)), isFalse);
      expect(
        isIdempotencyKeyConsumed(DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.receiveTimeout,
        )),
        isFalse,
      );
      expect(isIdempotencyKeyConsumed(Exception('boom')), isFalse);
    });
  });

  group('Spending limits input (#171 / #177)', () {
    test('prefill keeps the exact stored value', () {
      expect(formatLimitInput(150), '150');
      expect(formatLimitInput(150.75), '150.75');
      expect(formatLimitInput(150.5), '150.5');
      expect(formatLimitInput(0.5), '0.5');
    });

    test('confirming an unchanged prefill round-trips the stored limit', () {
      for (final v in [150.75, 120.5, 0.25, 75.0]) {
        expect(parseLimitInput(formatLimitInput(v)), v);
      }
    });

    test('Arabic-Indic digits are accepted; invalid values are rejected (not silently ignored)', () {
      expect(parseLimitInput('٢٠٠'), 200.0);
      expect(parseLimitInput('0'), 0.0);
      expect(parseLimitInput('abc'), isNull);
      expect(parseLimitInput('-5'), isNull);
      expect(parseLimitInput(''), isNull);
    });
  });

  group('MFA settings input (#188 / C1)', () {
    test('TOTP codes typed with Arabic-Indic digits are sent as ASCII', () {
      expect(normalizeTotpInput('٤٨٢٩١٧'), '482917');
      expect(normalizeTotpInput(' 123 456 '), '123456');
      expect(normalizeTotpInput('12345'), isNull);
      expect(normalizeTotpInput('12a456'), isNull);
    });

    test('second factor: TOTP goes to code, recovery codes are normalized', () {
      expect(buildMfaSecondFactor('١٢٣٤٥٦'), {'code': '123456'});
      expect(buildMfaSecondFactor('abcd-efgh-2345-6789'), {'recovery_code': 'ABCDEFGH23456789'});
      expect(buildMfaSecondFactor('ABCD EFGH 2345 6789'), {'recovery_code': 'ABCDEFGH23456789'});
      expect(buildMfaSecondFactor('7k4m-qx2p'), {'recovery_code': '7K4MQX2P'});
      expect(buildMfaSecondFactor('ABCD-EFG'), isNull);
      expect(buildMfaSecondFactor('12345'), isNull);
      expect(buildMfaSecondFactor(''), isNull);
    });
  });

  group('Add child PIN (#188)', () {
    test('Arabic-Indic PIN is accepted and sent as ASCII digits', () {
      expect(normalizeChildPin('١٢٣٤٥٦'), '123456');
      expect(normalizeChildPin(' 654321 '), '654321');
      expect(normalizeChildPin('12345'), isNull);
      expect(normalizeChildPin('12a456'), isNull);
      expect(normalizeChildPin('+12345'), isNull);
    });
  });

  group('Parent coach history (#191 / C15)', () {
    test('sends prior turns only, skipping the greeting and error bubbles', () {
      final history = buildParentCoachHistory([
        {'role': 'assistant', 'text': 'أهلاً بك!', 'local': 'true'},
        {'role': 'user', 'text': 'سؤال 1'},
        {'role': 'assistant', 'text': 'إجابة 1'},
        {'role': 'user', 'text': 'سؤال 2'},
        {'role': 'assistant', 'text': 'تعذر الاتصال', 'local': 'true'},
      ]);
      expect(history, [
        {'role': 'user', 'content': 'سؤال 1'},
        {'role': 'assistant', 'content': 'إجابة 1'},
        {'role': 'user', 'content': 'سؤال 2'},
      ]);
    });

    test('keeps only the last 10 messages, oldest first', () {
      final msgs = [
        for (var i = 0; i < 14; i++) {'role': i.isEven ? 'user' : 'assistant', 'text': 'm$i'},
      ];
      final history = buildParentCoachHistory(msgs);
      expect(history.length, 10);
      expect(history.first['content'], 'm4');
      expect(history.last['content'], 'm13');
    });

    test('respects the backend per-item and total size limits', () {
      final long = buildParentCoachHistory([
        {'role': 'user', 'text': 'a' * 1500},
      ]);
      expect(long.single['content']!.length, 1000);

      final big = buildParentCoachHistory([
        for (var i = 0; i < 6; i++) {'role': 'user', 'text': '$i${'b' * 899}'},
      ]);
      final total = big.fold<int>(0, (s, m) => s + m['content']!.runes.length);
      expect(total, lessThanOrEqualTo(4000));
      expect(big.length, 4);
      expect(big.last['content']!.startsWith('5'), isTrue);
    });
  });

  group('Dashboard transaction date (#262 / C14)', () {
    test('the overview date is already Egypt-local and is shown as is (converted exactly once, server-side)', () {
      // backend: 22:30 UTC -> "2026-07-15 01:30" (Cairo). Re-reading it as UTC would show 04:30 on a Cairo device.
      expect(formatOverviewTxnDate('2026-07-15 01:30'), '2026-07-15 01:30');
      expect(formatOverviewTxnDate(' 2026-10-22 21:52 '), '2026-10-22 21:52');
    });

    test('a timestamp with an explicit offset is converted to device local time', () {
      final local = DateTime.utc(2026, 10, 22, 21, 52).toLocal();
      String two(int v) => v.toString().padLeft(2, '0');
      final expected = '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
      expect(formatOverviewTxnDate('2026-10-22T21:52:00Z'), expected);
      expect(formatOverviewTxnDate('2026-10-23T00:52:00+03:00'), expected);
    });

    test('missing or unparseable dates never crash', () {
      expect(formatOverviewTxnDate(null), '');
      expect(formatOverviewTxnDate(''), '');
      expect(formatOverviewTxnDate('not a date'), 'not a date');
    });
  });

  group('Screen wiring against a fake API', () {
    late HttpClientAdapter originalAdapter;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      originalAdapter = ApiClient().dio.httpClientAdapter;
    });

    tearDown(() {
      ApiClient().dio.httpClientAdapter = originalAdapter;
    });

    testWidgets('#166 both sources failing shows the error view with retry, never "all reviewed"', (tester) async {
      var failing = true;
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.familyChildren) return _json(200, {'children': []});
        if (failing) return _json(500, {'detail': 'Internal Server Error'});
        return _json(200, []);
      });

      await tester.pumpWidget(const MaterialApp(home: ApprovalsScreen()));
      await _settle(tester);
      expect(find.text(_allReviewed), findsNothing);
      expect(find.text('إعادة المحاولة'), findsOneWidget);

      failing = false;
      await tester.tap(find.text('إعادة المحاولة'));
      await _settle(tester);
      expect(find.text('إعادة المحاولة'), findsNothing);
      expect(find.text(_allReviewed), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('#166 one source failing keeps what loaded and shows a warning banner', (tester) async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.familyChildren) return _json(200, {'children': []});
        if (options.path.startsWith('/card/purchases/family')) {
          return _json(500, {'detail': 'Internal Server Error'});
        }
        return _json(200, [_submittedChore]);
      });

      await tester.pumpWidget(const MaterialApp(home: ApprovalsScreen()));
      await _settle(tester);
      expect(find.textContaining('تعذر تحميل مشتريات البطاقة'), findsOneWidget);
      expect(find.text('ترتيب السرير'), findsOneWidget);
      expect(find.text(_allReviewed), findsNothing);
    });

    testWidgets('#165 pull-to-refresh works on the empty state and shows new requests', (tester) async {
      var missionsCalls = 0;
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.familyChildren) return _json(200, {'children': []});
        if (options.path.startsWith('/missions/family')) {
          missionsCalls++;
          return _json(200, missionsCalls == 1 ? <Object>[] : <Object>[_submittedChore]);
        }
        return _json(200, []);
      });

      await tester.pumpWidget(const MaterialApp(home: ApprovalsScreen()));
      await _settle(tester);
      expect(find.text(_allReviewed), findsOneWidget);
      expect(missionsCalls, 1);

      await tester.fling(find.text(_allReviewed), const Offset(0.0, 300.0), 1000.0);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // finish the scroll animation
      await tester.pump(const Duration(seconds: 1)); // finish the indicator settle animation
      await tester.pump(const Duration(seconds: 1)); // finish the indicator hide animation

      expect(missionsCalls, 2);
      expect(find.text('ترتيب السرير'), findsOneWidget);
      expect(find.text(_allReviewed), findsNothing);
    });

    testWidgets('#173 a double tap on approve sends exactly one review; both buttons stay disabled meanwhile',
        (tester) async {
      final reviewGate = Completer<ResponseBody>();
      var reviewPosts = 0;
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.familyChildren) return _json(200, {'children': []});
        if (options.path.startsWith('/missions/family')) return _json(200, []);
        if (options.path.startsWith('/card/purchases/family')) return _json(200, [_pendingPurchase]);
        if (options.path == '/card/purchases/p1/review') {
          reviewPosts++;
          return reviewGate.future;
        }
        return _json(404, {'detail': 'Not Found'});
      });

      await tester.pumpWidget(const MaterialApp(home: ApprovalsScreen()));
      await _settle(tester);

      final approve = find.text('موافقة على الشراء');
      expect(approve, findsOneWidget);
      await tester.tap(approve);
      await tester.tap(approve); // lands before the next frame rebuilds the card
      await _settle(tester);
      expect(reviewPosts, 1);

      ButtonStyleButton buttonWithLabel(String label) => tester.widget<ButtonStyleButton>(
            find.ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
            ),
          );
      expect(buttonWithLabel('موافقة على الشراء').onPressed, isNull);
      expect(buttonWithLabel('رفض').onPressed, isNull);

      reviewGate.complete(_json(200, {'id': 'p1', 'status': 'completed'}));
      await _settle(tester);
      expect(reviewPosts, 1);
      expect(find.text('Toy Shop'), findsNothing);
      await _drainSnackBars(tester);
    });

    testWidgets('#180 / #184 bumping the tab refresh signal reloads approvals and allowance', (tester) async {
      final approvalsSignal = ValueNotifier<int>(0);
      final allowanceSignal = ValueNotifier<int>(0);
      var missionsCalls = 0;
      var overviewCalls = 0;
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.familyChildren) return _json(200, {'children': []});
        if (options.path == ApiConfig.familyOverview) {
          overviewCalls++;
          return _json(200, {'children': []});
        }
        if (options.path.startsWith('/missions/family')) missionsCalls++;
        return _json(200, []);
      });

      await tester.pumpWidget(MaterialApp(home: ApprovalsScreen(refreshSignal: approvalsSignal)));
      await _settle(tester);
      expect(missionsCalls, 1);
      approvalsSignal.value++;
      await _settle(tester);
      expect(missionsCalls, 2);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(MaterialApp(home: AllowanceScreen(refreshSignal: allowanceSignal)));
      await _settle(tester);
      expect(overviewCalls, 1);
      allowanceSignal.value++;
      await _settle(tester);
      expect(overviewCalls, 2);

      await tester.pumpWidget(const SizedBox());
      approvalsSignal.dispose();
      allowanceSignal.dispose();
    });

    Future<List<Map<dynamic, dynamic>>> pumpAllowance(
      WidgetTester tester,
      List<FutureOr<ResponseBody>> allowanceReplies,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final allowancePosts = <Map<dynamic, dynamic>>[];
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.familyOverview) {
          return _json(200, {
            'children': [
              {'id': 'c1', 'full_name': 'منى', 'avatar': '👧', 'balance': 10.0},
            ],
          });
        }
        if (options.path.endsWith('/allowance')) {
          allowancePosts.add(options.data as Map);
          return allowanceReplies.removeAt(0);
        }
        return _json(404, {'detail': 'Not Found'});
      });

      await tester.pumpWidget(const MaterialApp(home: AllowanceScreen()));
      await _settle(tester);
      await tester.enterText(find.byType(TextFormField).first, '100');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      return allowancePosts;
    }

    Future<void> pullToRefresh(WidgetTester tester) async {
      tester.widget<RefreshIndicator>(find.byType(RefreshIndicator)).onRefresh();
      await _settle(tester);
    }

    testWidgets('#169 a pull-to-refresh during an in-flight send keeps the idempotency key for the retry',
        (tester) async {
      final lostResponse = Completer<ResponseBody>();
      final posts = await pumpAllowance(tester, [lostResponse.future, _json(200, {'balance': 110.0})]);

      await tester.tap(find.text(_sendAllowanceLabel));
      await _settle(tester);
      expect(posts, hasLength(1));

      // Slow cold start: the parent pulls to refresh while the send is still pending
      await pullToRefresh(tester);

      // The response is lost after the server may have committed (not a 409): the retry must reuse the key
      lostResponse.complete(_json(500, {'detail': 'Internal Server Error'}));
      await _settle(tester);

      await tester.tap(find.text(_sendAllowanceLabel));
      await _settle(tester);
      expect(posts, hasLength(2));
      expect(posts[1]['idempotency_key'], isNotNull);
      expect(posts[1]['idempotency_key'], posts[0]['idempotency_key']);
      await _drainSnackBars(tester);
    });

    testWidgets('#169 a pull-to-refresh while idle makes the next send a new operation', (tester) async {
      final posts = await pumpAllowance(tester, [
        _json(500, {'detail': 'Internal Server Error'}),
        _json(200, {'balance': 110.0}),
      ]);

      await tester.tap(find.text(_sendAllowanceLabel));
      await _settle(tester);
      expect(posts, hasLength(1));

      // The parent has now seen the real balance
      await pullToRefresh(tester);

      await tester.tap(find.text(_sendAllowanceLabel));
      await _settle(tester);
      expect(posts, hasLength(2));
      expect(posts[1]['idempotency_key'], isNot(posts[0]['idempotency_key']));
      await _drainSnackBars(tester);
    });
  });
}
