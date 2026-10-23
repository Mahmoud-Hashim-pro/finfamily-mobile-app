import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finfamily_mobile/core/api_client.dart';
import 'package:finfamily_mobile/core/auth_state.dart';

/// HTTP adapter that simulates an unreachable backend (no real network in tests).
class _UnreachableAdapter implements HttpClientAdapter {
  int requestCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestCount++;
    throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final defaultRecoveryDelays = AuthState.profileRecoveryDelays;
  late HttpClientAdapter originalAdapter;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
    AuthState.profileRecoveryDelays = const [];
    originalAdapter = ApiClient().dio.httpClientAdapter;
  });

  tearDown(() {
    ApiClient().dio.httpClientAdapter = originalAdapter;
    AuthState.profileRecoveryDelays = defaultRecoveryDelays;
  });

  group('Session & Security Integration — Fail-Closed Role Isolation', () {
    test('Unverified session prevents privilege escalation to parent/child actions', () {
      final auth = AuthState();

      // State is unauthenticated / unverified initially
      expect(auth.status, anyOf(equals(AuthStatus.initial), equals(AuthStatus.loading)));
      expect(auth.isServerVerified, isFalse);
      expect(auth.isVerifiedParent, isFalse);
      expect(auth.isVerifiedChild, isFalse);
      expect(auth.isSuperAdmin, isFalse);
    });

    test('requireServerVerification returns false when server is unreachable', () async {
      // A stored session exists, but every /auth/me attempt fails at the network layer
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'finfamily_token': 'parent-token',
        'finfamily_role': 'parent',
      });
      final adapter = _UnreachableAdapter();
      ApiClient().dio.httpClientAdapter = adapter;

      final auth = AuthState();
      await auth.authInitialized;
      final requestsAfterStartup = adapter.requestCount;

      // requireServerVerification must really try the backend, then fail closed.
      final isVerified = await auth.requireServerVerification();
      expect(adapter.requestCount, greaterThan(requestsAfterStartup));
      expect(isVerified, isFalse);
      expect(auth.isServerVerified, isFalse);
      expect(auth.isVerifiedParent, isFalse);
      expect(auth.isRestoredOfflineSession, isTrue);
    });

    test('Super admin capability strictly demands verified server claims', () async {
      // Offline restore of a cached admin role must never grant super-admin capability
      FlutterSecureStorage.setMockInitialValues(<String, String>{
        'finfamily_token': 'admin-token',
        'finfamily_role': 'admin',
      });
      ApiClient().dio.httpClientAdapter = _UnreachableAdapter();

      final auth = AuthState();
      await auth.authInitialized;

      expect(auth.role, equals('admin'));
      expect(auth.isRestoredOfflineSession, isTrue);
      expect(auth.isSuperAdmin, isFalse);
      expect(auth.isVerifiedParent, isFalse);
    });

    test('State cleanly resets on logout without residual credentials', () async {
      final auth = AuthState();
      await auth.logout();

      expect(auth.status, equals(AuthStatus.unauthenticated));
      expect(auth.user, isNull);
      expect(auth.role, isNull);
      expect(auth.isServerVerified, isFalse);
      expect(auth.isRestoredOfflineSession, isFalse);
      expect(auth.tempLoginToken, isNull);
      expect(auth.pendingParentEmail, isNull);
    });
  });
}
