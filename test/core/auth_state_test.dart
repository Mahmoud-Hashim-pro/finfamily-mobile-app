import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finfamily_mobile/config/api_config.dart';
import 'package:finfamily_mobile/core/api_client.dart';
import 'package:finfamily_mobile/core/auth_state.dart';

/// Minimal in-memory HTTP adapter so AuthState can be exercised without a backend.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final FutureOr<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(int statusCode, Object body) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

Map<String, dynamic> _userPayload(String role) {
  // Mirrors backend UserResponse (backend/schemas/auth.py)
  return {
    'id': 'a1',
    'family_id': 'f1',
    'role': role,
    'full_name': 'Test User',
    'email': 'user@test.local',
    'created_date': '2026-01-01T00:00:00',
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final defaultRecoveryDelays = AuthState.profileRecoveryDelays;
  late HttpClientAdapter originalAdapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    // No background /auth/me retries in unit tests
    AuthState.profileRecoveryDelays = const [];
    originalAdapter = ApiClient().dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient().dio.httpClientAdapter = originalAdapter;
    AuthState.profileRecoveryDelays = defaultRecoveryDelays;
  });

  group('AuthState - Super-Admin Authorization (BUG-045, BUG-125)', () {
    test('isSuperAdmin is false for a fresh unauthenticated AuthState', () {
      final auth = AuthState();
      expect(auth.isSuperAdmin, isFalse);
    });

    test('isSuperAdmin is false when unauthenticated or unverified', () {
      final auth = AuthState();
      expect(auth.isSuperAdmin, isFalse);
      expect(auth.isParent, isFalse);
      expect(auth.isChild, isFalse);
      expect(auth.isServerVerified, isFalse);
      expect(auth.isVerifiedParent, isFalse);
      expect(auth.isVerifiedChild, isFalse);
    });

    test('isRestoredOfflineSession is false initially when unauthenticated', () {
      final auth = AuthState();
      expect(auth.isRestoredOfflineSession, isFalse);
    });

    test('isSuperAdmin is granted only for a server-verified admin claim', () async {
      final auth = AuthState();
      await auth.authInitialized;

      auth.debugSeedVerifiedSession(user: {'id': 'a1', 'role': 'admin'});
      expect(auth.isSuperAdmin, isTrue);

      auth.debugSeedVerifiedSession(user: {'id': 'a1', 'role': 'parent', 'is_admin': true});
      expect(auth.isSuperAdmin, isTrue);

      auth.debugSeedVerifiedSession(user: {'id': 'p1', 'role': 'parent'});
      expect(auth.isSuperAdmin, isFalse);
      expect(auth.isVerifiedParent, isTrue);
    });

    test('server-verified admin role from /auth/me grants super-admin', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'finfamily_token': 'test-token',
        'finfamily_role': 'admin',
      });
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        if (options.path == ApiConfig.currentUser) {
          return _jsonResponse(200, _userPayload('admin'));
        }
        return _jsonResponse(404, {'detail': 'Not Found'});
      });

      final auth = AuthState();
      await auth.authInitialized;

      expect(auth.isServerVerified, isTrue);
      expect(auth.isSuperAdmin, isTrue);
      expect(auth.role, equals('admin'));
    });

    test('server role is authoritative over a cached admin role', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'finfamily_token': 'test-token',
        'finfamily_role': 'admin',
      });
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _jsonResponse(200, _userPayload('parent'));
      });

      final auth = AuthState();
      await auth.authInitialized;

      expect(auth.isServerVerified, isTrue);
      expect(auth.role, equals('parent'));
      expect(auth.isSuperAdmin, isFalse);
    });

    test('an unverified offline session with a cached admin role never grants super-admin', () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'finfamily_token': 'test-token',
        'finfamily_role': 'admin',
      });
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
      });

      final auth = AuthState();
      await auth.authInitialized;

      expect(auth.status, equals(AuthStatus.authenticated));
      expect(auth.isRestoredOfflineSession, isTrue);
      expect(auth.isSuperAdmin, isFalse);
    });
  });

  group('AuthState - Session Verification and Verified Role Isolation', () {
    test('isVerifiedParent and isVerifiedChild fail closed when unverified', () {
      final auth = AuthState();
      expect(auth.isServerVerified, isFalse);
      expect(auth.isVerifiedParent, isFalse);
      expect(auth.isVerifiedChild, isFalse);
    });

    test('logout clears user, role, and resets server verified flag to false', () async {
      final auth = AuthState();
      await auth.logout();
      expect(auth.status, equals(AuthStatus.unauthenticated));
      expect(auth.user, isNull);
      expect(auth.role, isNull);
      expect(auth.isServerVerified, isFalse);
      expect(auth.isVerifiedParent, isFalse);
      expect(auth.isVerifiedChild, isFalse);
      expect(auth.pendingGoogleEmail, isNull);
      expect(auth.pendingGoogleName, isNull);
      expect(auth.isGoogleAccountUnregistered, isFalse);
    });

    test('logout clears Google pending state left by a previous Google attempt', () async {
      ApiClient().dio.httpClientAdapter = _FakeAdapter((options) {
        return _jsonResponse(404, {'detail': 'account not found'});
      });
      final auth = AuthState();
      await auth.authInitialized;

      // The interactive chooser records the picked account before the backend answers 404
      auth.debugSetPendingGoogleAccount(email: 'new.parent@gmail.com', name: 'New Parent');
      final ok = await auth.loginWithGoogle(manualIdToken: 'google-id-token');
      expect(ok, isFalse);
      expect(auth.isGoogleAccountUnregistered, isTrue);
      expect(auth.pendingGoogleEmail, 'new.parent@gmail.com');
      expect(auth.pendingGoogleName, 'New Parent');

      await auth.logout();
      expect(auth.isGoogleAccountUnregistered, isFalse);
      expect(auth.pendingGoogleEmail, isNull);
      expect(auth.pendingGoogleName, isNull);
    });

    test('initial google auth state is clean and unpopulated', () {
      final auth = AuthState();
      expect(auth.pendingGoogleEmail, isNull);
      expect(auth.pendingGoogleName, isNull);
      expect(auth.isGoogleAccountUnregistered, isFalse);
    });
  });

  group('AuthState - Child Stats Dynamic Updates (BUG-145)', () {
    test('updateChildStats is a no-op when no user is loaded', () {
      final auth = AuthState();
      int notificationCount = 0;
      auth.addListener(() {
        notificationCount++;
      });

      // Initially user is null, updateChildStats safely does nothing
      auth.updateChildStats(xp: 150, level: 3, streak: 5, balance: 250.0);
      expect(auth.user, isNull);
      expect(notificationCount, 0);
    });

    test('updateChildStats mutates in-memory user map and notifies listeners', () async {
      final auth = AuthState();
      await auth.authInitialized;
      auth.debugSeedVerifiedSession(user: {'id': 'c1', 'role': 'child', 'xp': 10, 'level': 1, 'streak': 1});

      int notificationCount = 0;
      auth.addListener(() {
        notificationCount++;
      });

      auth.updateChildStats(xp: 150, level: 3, streak: 5, balance: 250.0);
      expect(auth.user?['xp'], equals(150));
      expect(auth.user?['level'], equals(3));
      expect(auth.user?['streak'], equals(5));
      expect(auth.user?['balance'], equals(250.0));
      expect(notificationCount, 1);
    });
  });
}
