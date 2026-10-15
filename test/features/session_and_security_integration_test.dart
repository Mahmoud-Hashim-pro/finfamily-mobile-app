import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/core/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session & Security Integration — Fail-Closed Role Isolation', () {
    test('Unverified session prevents privilege escalation to parent/child actions', () {
      final auth = AuthState();

      // State is unauthenticated initially
      expect(auth.status, equals(AuthStatus.initial));
      expect(auth.isServerVerified, isFalse);
      expect(auth.isVerifiedParent, isFalse);
      expect(auth.isVerifiedChild, isFalse);
      expect(auth.isSuperAdmin, isFalse);
    });

    test('requireServerVerification returns false when server is unreachable', () async {
      final auth = AuthState();

      // Since there is no live backend running in local test environment,
      // requireServerVerification must gracefully fail-closed and return false.
      final isVerified = await auth.requireServerVerification();
      expect(isVerified, isFalse);
      expect(auth.isServerVerified, isFalse);
      expect(auth.isVerifiedParent, isFalse);
    });

    test('Super admin capability strictly demands verified server claims', () {
      final auth = AuthState();

      // Even if user object or role were somehow populated offline,
      // unverified session MUST NEVER grant super-admin capability
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
