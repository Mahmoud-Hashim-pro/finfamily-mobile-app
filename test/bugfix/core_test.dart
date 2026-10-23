// Regression tests for the MO-CORE bug-fix cluster (auth state, session handling,
// error translation, parsing helpers, update checker and shared widgets).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finfamily_mobile/config/api_config.dart';
import 'package:finfamily_mobile/core/api_client.dart';
import 'package:finfamily_mobile/core/auth_state.dart';
import 'package:finfamily_mobile/core/date_utils.dart';
import 'package:finfamily_mobile/core/error_handler.dart';
import 'package:finfamily_mobile/core/update_checker.dart';
import 'package:finfamily_mobile/features/auth/role_select_screen.dart';
import 'package:finfamily_mobile/main.dart';
import 'package:finfamily_mobile/models/card_model.dart';
import 'package:finfamily_mobile/models/mission_model.dart';
import 'package:finfamily_mobile/models/transaction_model.dart';
import 'package:finfamily_mobile/widgets/custom_button.dart';
import 'package:finfamily_mobile/widgets/custom_text_field.dart';
import 'package:finfamily_mobile/widgets/meeza_card_widget.dart';

const _sessionExpiredMsg = 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً';
const _mfaExpiredMsg = 'انتهت مهلة التحقق الثنائي، يرجى تسجيل الدخول مجدداً';
const _serverBusyMsg = 'الخادم مشغول حالياً أو استغرق وقتاً أطول من المتوقع، يرجى المحاولة بعد قليل';

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

Map<String, dynamic> _user(String role, [Map<String, dynamic> extra = const {}]) {
  return {
    'id': 'u1',
    'family_id': 'f1',
    'role': role,
    'full_name': 'Test User',
    'email': 'user@test.local',
    'created_date': '2026-01-01T00:00:00',
    ...extra,
  };
}

DioException _dioError(int? statusCode, dynamic data, {DioExceptionType type = DioExceptionType.badResponse}) {
  final requestOptions = RequestOptions(path: '/api/test');
  return DioException(
    requestOptions: requestOptions,
    type: type,
    response: statusCode == null
        ? null
        : Response(requestOptions: requestOptions, statusCode: statusCode, data: data),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final defaultRecoveryDelays = AuthState.profileRecoveryDelays;
  late Map<String, String> secureData;
  late HttpClientAdapter originalAdapter;

  setUp(() {
    secureData = <String, String>{};
    FlutterSecureStorage.setMockInitialValues(secureData);
    SharedPreferences.setMockInitialValues({});
    AuthState.profileRecoveryDelays = const [];
    originalAdapter = ApiClient().dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient().dio.httpClientAdapter = originalAdapter;
    AuthState.profileRecoveryDelays = defaultRecoveryDelays;
  });

  group('C6 normalizeArabicDigits (#155 #170 #234 #244)', () {
    test('thousands separators are removed instead of becoming a decimal point', () {
      expect(normalizeArabicDigits('1,000'), '1000');
      expect(normalizeArabicDigits('100,000'), '100000');
      expect(normalizeArabicDigits('1,500.25'), '1500.25');
      expect(double.tryParse(normalizeArabicDigits('1,500')), 1500.0);
    });

    test('Arabic thousands / decimal separators and digits are handled', () {
      expect(normalizeArabicDigits('١٬٥٠٠'), '1500');
      expect(normalizeArabicDigits('١،٥٠٠'), '1500');
      expect(normalizeArabicDigits('٢٫٥'), '2.5');
      expect(normalizeArabicDigits('۱۲۳'), '123');
    });

    test('a lone comma used as decimal mark keeps working', () {
      expect(normalizeArabicDigits('12,5'), '12.5');
      expect(normalizeArabicDigits('12,50'), '12.50');
      expect(normalizeArabicDigits('0,500'), '0.500');
    });
  });

  group('C8 parseServerDateTime (#156)', () {
    test('naive backend timestamps are treated as UTC', () {
      final parsed = parseServerDateTime('2026-10-22T22:30:00.123456');
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isFalse);
      expect(parsed.toUtc(), DateTime.utc(2026, 10, 22, 22, 30, 0, 123, 456));
    });

    test('explicit Z / offsets keep their instant', () {
      expect(parseServerDateTime('2026-10-22T22:30:00Z')!.toUtc(), DateTime.utc(2026, 10, 22, 22, 30));
      expect(parseServerDateTime('2026-10-22T22:30:00+02:00')!.toUtc(), DateTime.utc(2026, 10, 22, 20, 30));
    });

    test('missing or invalid values return null; date-only stays a calendar date', () {
      expect(parseServerDateTime(null), isNull);
      expect(parseServerDateTime(''), isNull);
      expect(parseServerDateTime('garbage'), isNull);
      final dateOnly = parseServerDateTime('2026-10-22')!;
      expect([dateOnly.year, dateOnly.month, dateOnly.day], [2026, 10, 22]);
    });

    test('TransactionModel parses naive created_date as UTC and rejects missing dates', () {
      final tx = TransactionModel.fromJson({
        'id': 'tx-1',
        'amount': 80,
        'direction': 'debit',
        'created_date': '2026-10-22T11:00:00',
      });
      expect(tx.date.toUtc(), DateTime.utc(2026, 10, 22, 11));

      expect(
        () => TransactionModel.fromJson({'id': 'tx-2', 'amount': 5, 'direction': 'debit'}),
        throwsFormatException,
      );
      expect(
        () => TransactionModel.fromJson({
          'id': 'tx-3',
          'amount': 5,
          'direction': 'debit',
          'created_date': 'garbage',
        }),
        throwsFormatException,
      );
    });
  });

  group('MissionModel XP (#161)', () {
    test('derives XP like the backend: int(reward) for chores, none for redemptions', () {
      expect(MissionModel.fromJson({'id': 'm1', 'reward': 15, 'kind': 'chore'}).rewardXp, 15);
      expect(MissionModel.fromJson({'id': 'm2', 'reward': 15.9, 'kind': 'chore'}).rewardXp, 15);
      expect(MissionModel.fromJson({'id': 'm3', 'reward': 30, 'kind': 'redemption'}).rewardXp, 0);
      expect(MissionModel.fromJson({'id': 'm4', 'reward': 15, 'reward_xp': 40}).rewardXp, 40);
    });
  });

  group('ApiErrorHandler (#149 #103 #150 #120)', () {
    test('expired / revoked session details show the session-expired message', () {
      expect(ApiErrorHandler.getErrorMessage(_dioError(401, {'detail': 'Invalid or expired token'})), _sessionExpiredMsg);
      expect(ApiErrorHandler.getErrorMessage(_dioError(401, {'detail': 'Token has been revoked'})), _sessionExpiredMsg);
      expect(
        ApiErrorHandler.getErrorMessage(_dioError(401, {'detail': 'Invalid or expired admin session token.'})),
        _sessionExpiredMsg,
      );
    });

    test('expired MFA challenge asks to log in again instead of the reset-link message', () {
      expect(
        ApiErrorHandler.getErrorMessage(_dioError(401, {'detail': 'Invalid or expired temporary session'})),
        _mfaExpiredMsg,
      );
      expect(
        ApiErrorHandler.getErrorMessage(_dioError(401, {'detail': 'Invalid or expired temporary admin session'})),
        _mfaExpiredMsg,
      );
      expect(
        ApiErrorHandler.getErrorMessage(_dioError(400, {'detail': 'This reset link is invalid or has expired.'})),
        'رابط أو رمز إعادة التعيين غير صالح أو منتهي الصلاحية',
      );
    });

    test('Google identity-proof failures are translated, never shown as an expired session (C13)', () {
      const mismatch = 'حساب Google الذي اخترته لا يطابق حسابك في FinFamily، يرجى اختيار نفس الحساب';
      const invalid = 'تعذر التحقق من حساب Google، يرجى المحاولة مرة أخرى';
      expect(
        ApiErrorHandler.getErrorMessage(
          _dioError(401, {'detail': 'Google authentication does not match account identity'}),
        ),
        mismatch,
      );
      expect(
        ApiErrorHandler.getErrorMessage(
          _dioError(401, {'detail': 'Invalid Google re-authentication token: identity mismatch'}),
        ),
        mismatch,
      );
      expect(
        ApiErrorHandler.getErrorMessage(
          _dioError(401, {'detail': 'Invalid Google ID token: Google ID token has expired'}),
        ),
        invalid,
      );
      expect(
        ApiErrorHandler.getErrorMessage(
          _dioError(401, {'detail': 'Google re-authentication is required for accounts without a password'}),
        ),
        'يرجى تأكيد هويتك عبر Google للمتابعة',
      );
    });

    test('goal errors are translated', () {
      expect(
        ApiErrorHandler.getErrorMessage(_dioError(400, {'detail': 'Deposit exceeds savings goal target'})),
        'المبلغ يتجاوز المبلغ المطلوب للهدف',
      );
      expect(
        ApiErrorHandler.getErrorMessage(_dioError(400, {'detail': 'Not enough savings in this goal'})),
        'المبلغ المحوّش في الهدف غير كافٍ للسحب',
      );
    });

    test('5xx and body-less errors never leak the raw DioException text', () {
      final timeout504 = ApiErrorHandler.getErrorMessage(
        _dioError(504, 'An error occurred with your deployment\n\nFUNCTION_INVOCATION_TIMEOUT'),
      );
      expect(timeout504, _serverBusyMsg);
      expect(ApiErrorHandler.getErrorMessage(_dioError(502, null)), _serverBusyMsg);
      expect(ApiErrorHandler.getErrorMessage(_dioError(503, null)), _serverBusyMsg);
      expect(ApiErrorHandler.getErrorMessage(_dioError(500, null)), 'حدث خطأ في الخادم، يرجى المحاولة لاحقاً');
      expect(ApiErrorHandler.getErrorMessage(_dioError(418, null)), 'تعذر إتمام الطلب، يرجى المحاولة مرة أخرى');
      expect(
        ApiErrorHandler.getErrorMessage(_dioError(null, null, type: DioExceptionType.cancel)),
        'تم إلغاء الطلب',
      );
      final unknown = ApiErrorHandler.getErrorMessage(_dioError(null, null, type: DioExceptionType.unknown));
      expect(unknown, isNot(contains('DioException')));
    });
  });

  group('Update checker & app version (#146 #22 #154 #151)', () {
    test('ApiConfig version defaults match pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(r'^version:\s*([0-9.]+)\+(\d+)', multiLine: true).firstMatch(pubspec);
      expect(match, isNotNull);
      expect(ApiConfig.currentAppVersion, match!.group(1));
      expect(ApiConfig.currentAppBuildNumber, int.parse(match.group(2)!));
    });

    test('isBelowMinimumSupported forces updates only below the minimum', () {
      expect(UpdateChecker.isBelowMinimumSupported('1.1.4', '1.1.2'), isTrue);
      expect(UpdateChecker.isBelowMinimumSupported('v1.2', '1.1.9'), isTrue);
      expect(UpdateChecker.isBelowMinimumSupported('1.1.4', '1.1.4'), isFalse);
      expect(UpdateChecker.isBelowMinimumSupported('1.0.0', '1.1.4'), isFalse);
      expect(UpdateChecker.isBelowMinimumSupported(null, '1.1.4'), isFalse);
      expect(UpdateChecker.isBelowMinimumSupported('', '1.1.4'), isFalse);
    });
  });

  group('C2 admin login with mandatory MFA (#0 #32 #92 #141)', () {
    test('challenge token is never persisted and verifyAdminMfa completes the session', () async {
      final adapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.adminLogin) {
          return _json(200, {
            'mfa_required': true,
            'mfa_enrollment_required': true,
            'access_token': 'challenge-token',
            'token_type': 'bearer',
            'secret': 'JBSWY3DPEHPK3PXP',
            'provisioning_uri': 'otpauth://totp/FinFamily:admin@test.local?secret=JBSWY3DPEHPK3PXP',
            'qr_code': 'data:image/png;base64,AAAA',
          });
        }
        if (options.path == ApiConfig.adminMfaVerify) {
          return _json(200, {
            'access_token': 'admin-session-token',
            'token_type': 'bearer',
            'admin': {'id': 'u1', 'full_name': 'Admin', 'email': 'admin@test.local', 'role': 'admin'},
            'recovery_codes': ['AAAA-BBBB-CCCC-DDDD'],
          });
        }
        if (options.path == ApiConfig.currentUser) {
          return _json(200, _user('parent'));
        }
        return _json(404, {'detail': 'Not Found'});
      });
      ApiClient().dio.httpClientAdapter = adapter;

      final auth = AuthState();
      await auth.authInitialized;

      final loggedIn = await auth.loginAdmin('Admin@Test.local ', 'admin-password');
      expect(loggedIn, isFalse);
      expect(auth.status, AuthStatus.requiresMfa);
      expect(auth.adminMfaPending, isTrue);
      expect(auth.adminMfaEnrollmentRequired, isTrue);
      expect(auth.adminMfaSecret, 'JBSWY3DPEHPK3PXP');
      expect(auth.adminMfaQrCode, startsWith('data:image/png;base64,'));
      expect(auth.adminMfaProvisioningUri, startsWith('otpauth://'));
      expect(secureData.containsKey('finfamily_token'), isFalse);
      expect(adapter.requests.any((r) => r.path == ApiConfig.currentUser), isFalse);

      final verified = await auth.verifyAdminMfa(' ١٢٣ ٤٥٦ ');
      expect(verified, isTrue);
      final verifyRequest = adapter.requests.firstWhere((r) => r.path == ApiConfig.adminMfaVerify);
      expect(verifyRequest.data, {'temp_token': 'challenge-token', 'code': '123456'});
      expect(secureData['finfamily_token'], 'admin-session-token');
      expect(adapter.requests.last.headers['Authorization'], 'Bearer admin-session-token');
      expect(auth.status, AuthStatus.authenticated);
      expect(auth.adminMfaPending, isFalse);
      expect(auth.adminMfaSecret, isNull);
      expect(auth.adminRecoveryCodes, ['AAAA-BBBB-CCCC-DDDD']);

      auth.clearAdminRecoveryCodes();
      expect(auth.adminRecoveryCodes, isNull);
    });

    test('wrong code keeps the MFA step; an expired challenge returns to login', () async {
      var verifyCalls = 0;
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.adminLogin) {
          return _json(200, {
            'mfa_required': true,
            'mfa_enrollment_required': false,
            'access_token': 'challenge-token',
            'token_type': 'bearer',
          });
        }
        if (options.path == ApiConfig.adminMfaVerify) {
          verifyCalls++;
          return verifyCalls == 1
              ? _json(401, {'detail': 'Invalid authentication code'})
              : _json(401, {'detail': 'Invalid or expired temporary admin session'});
        }
        return _json(404, {'detail': 'Not Found'});
      });

      final auth = AuthState();
      await auth.authInitialized;
      expect(await auth.loginAdmin('admin@test.local', 'pw'), isFalse);
      expect(auth.adminMfaEnrollmentRequired, isFalse);

      expect(await auth.verifyAdminMfa('000000'), isFalse);
      expect(auth.status, AuthStatus.requiresMfa);
      expect(auth.adminMfaPending, isTrue);

      expect(await auth.verifyAdminMfa('111111'), isFalse);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.adminMfaPending, isFalse);
      expect(auth.tempLoginToken, isNull);
      expect(auth.errorMessage, _mfaExpiredMsg);
      expect(secureData.containsKey('finfamily_token'), isFalse);
    });

    test('cancelAdminMfa discards the pending challenge', () async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(200, {'mfa_required': true, 'mfa_enrollment_required': false, 'access_token': 'challenge-token'});
      });
      final auth = AuthState();
      await auth.authInitialized;
      await auth.loginAdmin('admin@test.local', 'pw');
      expect(auth.adminMfaPending, isTrue);

      auth.cancelAdminMfa();
      expect(auth.adminMfaPending, isFalse);
      expect(auth.tempLoginToken, isNull);
      expect(auth.status, AuthStatus.unauthenticated);
    });
  });

  group('C1 / C3 parent MFA (#142 #143 #105 #149)', () {
    test('dashed lowercase recovery codes are normalized before /auth/mfa/verify', () async {
      final adapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.parentLogin) {
          return _json(200, {'mfa_required': true, 'temp_token': 'parent-challenge'});
        }
        if (options.path == ApiConfig.mfaVerify) {
          return _json(200, {'access_token': 'parent-session', 'token_type': 'bearer', 'user': _user('parent')});
        }
        return _json(200, _user('parent'));
      });
      ApiClient().dio.httpClientAdapter = adapter;

      final auth = AuthState();
      await auth.authInitialized;
      expect(await auth.loginParent('parent@test.local', ' pass word '), isFalse);
      expect(adapter.requests.first.data['password'], ' pass word ');
      expect(auth.status, AuthStatus.requiresMfa);

      expect(await auth.loginParentWithRecovery('5kgh-jyrk e9ef-paky'), isTrue);
      final verifyRequest = adapter.requests.firstWhere((r) => r.path == ApiConfig.mfaVerify);
      expect(verifyRequest.data, {'temp_token': 'parent-challenge', 'code': '5KGHJYRKE9EFPAKY'});
      expect(auth.status, AuthStatus.authenticated);
      expect(secureData['finfamily_token'], 'parent-session');
    });

    test('an expired MFA challenge ends the MFA step instead of looping', () async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.parentLogin) {
          return _json(200, {'mfa_required': true, 'temp_token': 'parent-challenge'});
        }
        return _json(401, {'detail': 'Invalid or expired temporary session'});
      });

      final auth = AuthState();
      await auth.authInitialized;
      await auth.loginParent('parent@test.local', 'pw');

      expect(await auth.verifyMfa('123456'), isFalse);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.tempLoginToken, isNull);
      expect(auth.errorMessage, _mfaExpiredMsg);
    });

    test('Google sign-in with MFA keeps the challenge for verifyMfa and sends the typed family name', () async {
      final adapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.googleLogin) {
          return _json(200, {'mfa_required': true, 'temp_token': 'google-challenge'});
        }
        if (options.path == ApiConfig.mfaVerify) {
          return _json(200, {'access_token': 'google-session', 'token_type': 'bearer', 'user': _user('parent')});
        }
        return _json(200, _user('parent'));
      });
      ApiClient().dio.httpClientAdapter = adapter;

      final auth = AuthState();
      await auth.authInitialized;

      final ok = await auth.loginWithGoogle(
        manualIdToken: 'google-id-token',
        createIfMissing: true,
        familyName: '  عائلة حسن  ',
      );
      expect(ok, isFalse);
      expect(auth.status, AuthStatus.requiresMfa);
      expect(auth.tempLoginToken, 'google-challenge');
      final googleRequest = adapter.requests.firstWhere((r) => r.path == ApiConfig.googleLogin);
      expect(googleRequest.data['family_name'], 'عائلة حسن');

      expect(await auth.verifyMfa('123456'), isTrue);
      final verifyRequest = adapter.requests.firstWhere((r) => r.path == ApiConfig.mfaVerify);
      expect(verifyRequest.data['temp_token'], 'google-challenge');
      expect(secureData['finfamily_token'], 'google-session');

      // Plain Google login never sends a family name
      await auth.loginWithGoogle(manualIdToken: 'google-id-token', familyName: 'عائلة حسن');
      final loginRequest = adapter.requests.lastWhere((r) => r.path == ApiConfig.googleLogin);
      expect((loginRequest.data as Map).containsKey('family_name'), isFalse);
    });
  });

  group('C13 hasPassword', () {
    test('defaults to true and follows has_password from /auth/me', () async {
      final auth = AuthState();
      await auth.authInitialized;
      expect(auth.hasPassword, isTrue);

      auth.debugSeedVerifiedSession(user: _user('parent'));
      expect(auth.hasPassword, isTrue);

      auth.debugSeedVerifiedSession(user: _user('parent', {'has_password': false}));
      expect(auth.hasPassword, isFalse);
    });
  });

  group('Restored admin session keeps the admin role (#0 #199)', () {
    String jwt(Map<String, dynamic> claims) {
      String seg(Object o) => base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
      return '${seg({'alg': 'HS256', 'typ': 'JWT'})}.${seg(claims)}.sig';
    }

    test('an admin-claims token stays admin although /auth/me reports the DB role parent', () async {
      secureData['finfamily_token'] = jwt({'sub': 'u1', 'role': 'admin', 'is_admin': true});
      secureData['finfamily_role'] = 'admin';
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) => _json(200, _user('parent')));

      final auth = AuthState();
      await auth.authInitialized;

      expect(auth.role, 'admin');
      expect(auth.isSuperAdmin, isTrue);
      expect(secureData['finfamily_role'], 'admin');
    });

    test('a cached admin role with a plain parent token is downgraded to the server role', () async {
      secureData['finfamily_token'] = jwt({'sub': 'u1', 'role': 'parent'});
      secureData['finfamily_role'] = 'admin';
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) => _json(200, _user('parent')));

      final auth = AuthState();
      await auth.authInitialized;

      expect(auth.role, 'parent');
      expect(auth.isSuperAdmin, isFalse);
      expect(secureData['finfamily_role'], 'parent');
    });
  });

  group('C4 session invalidation & 401 handling (#144 #183 #148 #145)', () {
    test('a 401 on a live session signals sessionExpired exactly once', () async {
      secureData['finfamily_token'] = 'live-token';
      secureData['finfamily_role'] = 'parent';
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.currentUser) return _json(200, _user('parent'));
        return _json(401, {'detail': 'Token has been revoked'});
      });

      final auth = AuthState();
      await auth.authInitialized;
      expect(auth.status, AuthStatus.authenticated);

      var fired = 0;
      auth.sessionExpired.addListener(() => fired++);

      await expectLater(ApiClient().get(ApiConfig.familyOverview), throwsA(isA<DioException>()));
      expect(fired, 1);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(secureData.containsKey('finfamily_token'), isFalse);

      // Follow-up 401s (now without a token) do not fire again
      await expectLater(ApiClient().get(ApiConfig.familyOverview), throwsA(isA<DioException>()));
      expect(fired, 1);
    });

    test('a token rejected during login confirmation fails the login without a session-expired signal', () async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.childLogin) {
          return _json(200, {'access_token': 'child-token', 'token_type': 'bearer', 'user': _user('child')});
        }
        return _json(401, {'detail': 'Token has been revoked'});
      });

      final auth = AuthState();
      await auth.authInitialized;
      var fired = 0;
      auth.sessionExpired.addListener(() => fired++);

      expect(await auth.loginChild('ABC123', 'c1', '1234'), isFalse);
      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.errorMessage, isNotNull);
      expect(fired, 0);
    });

    test('no session-expired signal after a manual logout', () async {
      secureData['finfamily_token'] = 'live-token';
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.currentUser) return _json(200, _user('child'));
        return _json(401, {'detail': 'Not authenticated'});
      });

      final auth = AuthState();
      await auth.authInitialized;
      var fired = 0;
      auth.sessionExpired.addListener(() => fired++);

      await auth.logout();
      await expectLater(ApiClient().get(ApiConfig.walletMe), throwsA(isA<DioException>()));
      expect(fired, 0);
    });

    test('a Google identity-proof 401 (wrong Google account) keeps the session (C13)', () async {
      secureData['finfamily_token'] = 'live-token';
      secureData['finfamily_role'] = 'parent';
      const googleFailures = {
        ApiConfig.mfaSetup: 'Google authentication does not match account identity',
        ApiConfig.mfaDisable: 'Invalid Google ID token: Google ID token has expired',
        ApiConfig.mfaRecoveryRegenerate: 'Invalid Google re-authentication token: identity mismatch',
      };
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.currentUser) return _json(200, _user('parent', {'has_password': false}));
        return _json(401, {'detail': googleFailures[options.path] ?? 'Token has been revoked'});
      });

      final auth = AuthState();
      await auth.authInitialized;
      expect(auth.status, AuthStatus.authenticated);
      var fired = 0;
      auth.sessionExpired.addListener(() => fired++);

      for (final path in googleFailures.keys) {
        await expectLater(
          ApiClient().post(path, data: {'google_id_token': 'other-google-account'}),
          throwsA(isA<DioException>()),
        );
      }
      expect(fired, 0);
      expect(auth.status, AuthStatus.authenticated);
      expect(secureData['finfamily_token'], 'live-token');
    });

    test('a 401 for a request sent with a replaced token does not wipe the new session', () async {
      secureData['finfamily_token'] = 'token-A';
      final previousHandler = ApiClient().onUnauthorized;
      var unauthorizedCalls = 0;
      ApiClient().onUnauthorized = () => unauthorizedCalls++;
      addTearDown(() => ApiClient().onUnauthorized = previousHandler);

      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        // The user logs in again while this request (sent with token A) is in flight
        secureData['finfamily_token'] = 'token-B';
        return _json(401, {'detail': 'Token has been revoked'});
      });
      await expectLater(ApiClient().get(ApiConfig.familyOverview), throwsA(isA<DioException>()));
      expect(secureData['finfamily_token'], 'token-B');
      expect(unauthorizedCalls, 0);

      // The same 401 for the current token still invalidates the session
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _json(401, {'detail': 'Token has been revoked'});
      });
      await expectLater(ApiClient().get(ApiConfig.familyOverview), throwsA(isA<DioException>()));
      expect(secureData.containsKey('finfamily_token'), isFalse);
      expect(unauthorizedCalls, 1);
    });

    test('a slow or failed startup /auth/me is retried and the profile recovered', () async {
      AuthState.profileRecoveryDelays = const [Duration(milliseconds: 10), Duration(milliseconds: 10)];
      secureData['finfamily_token'] = 'child-token';
      secureData['finfamily_role'] = 'child';
      var meCalls = 0;
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        meCalls++;
        if (meCalls == 1) {
          throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
        }
        return _json(200, _user('child', {'full_name': 'Child Hero'}));
      });

      final auth = AuthState();
      await auth.authInitialized;
      expect(auth.isRestoredOfflineSession, isTrue);
      expect(auth.user, isNull);

      for (var i = 0; i < 200 && !auth.isServerVerified; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(auth.isServerVerified, isTrue);
      expect(auth.user?['full_name'], 'Child Hero');
      expect(auth.role, 'child');
    });

    test('a /auth/me response that lands after logout does not restore the profile', () async {
      secureData['finfamily_token'] = 'parent-token';
      final gate = Completer<void>();
      var meCalls = 0;
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) async {
        meCalls++;
        if (meCalls >= 2) await gate.future;
        return _json(200, _user('parent'));
      });

      final auth = AuthState();
      await auth.authInitialized;
      expect(auth.isServerVerified, isTrue);

      final pending = auth.refreshCurrentUser();
      for (var i = 0; i < 200 && meCalls < 2; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      await auth.logout();
      gate.complete();
      await pending;

      expect(auth.status, AuthStatus.unauthenticated);
      expect(auth.user, isNull);
      expect(auth.isServerVerified, isFalse);
    });

    testWidgets('the app root returns to RoleSelectScreen when the live session expires', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      late AuthState auth;
      await tester.runAsync(() async {
        auth = AuthState();
        await auth.authInitialized;
      });
      auth.debugSeedVerifiedSession(user: _user('parent'));

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthState>.value(
          value: auth,
          child: const FinFamilyApp(home: Scaffold(body: Text('shell-home'))),
        ),
      );
      expect(find.text('shell-home'), findsOneWidget);

      // What ApiClient does on a session-invalidating 401
      ApiClient().onUnauthorized!();
      await tester.pumpAndSettle();

      expect(find.byType(RoleSelectScreen), findsOneWidget);
      expect(find.text('shell-home'), findsNothing);
      expect(find.text(_sessionExpiredMsg), findsOneWidget);

      // Let the snackbar finish before the tree is torn down
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });
  });

  group('Shared widgets (#157 #158 #159)', () {
    CardModel card({String status = 'active', String name = 'Test Child'}) {
      return CardModel(
        id: 'c1',
        userId: 'u1',
        cardNumber: '4000 1234 5678 9010',
        cardholderName: name,
        status: status,
        expiryDate: '12/29',
      );
    }

    Widget host(CardModel model) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 320, child: MeezaCardWidget(card: model)),
          ),
        ),
      );
    }

    testWidgets('a deactivated card never looks active, even without controls', (tester) async {
      await tester.pumpWidget(host(card(status: 'deactivated')));
      expect(find.text('ملغي'), findsOneWidget);
      expect(find.byIcon(Icons.contactless), findsNothing);

      await tester.pumpWidget(host(card()));
      expect(find.byIcon(Icons.contactless), findsOneWidget);
      expect(find.text('ملغي'), findsNothing);
    });

    testWidgets('a long cardholder name is ellipsized without overflow', (tester) async {
      await tester.pumpWidget(host(card(name: 'عبد الرحمن محمد عبد العزيز الشناوي ' * 3)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a loading CustomButton keeps its background so the spinner stays visible', (tester) async {
      const brand = Color(0xFF123456);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomButton(text: 'حفظ', onPressed: () {}, isLoading: true, backgroundColor: brand),
          ),
        ),
      );

      final material = tester.widget<Material>(
        find.descendant(of: find.byType(ElevatedButton), matching: find.byType(Material)).first,
      );
      expect(material.color, brand);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
