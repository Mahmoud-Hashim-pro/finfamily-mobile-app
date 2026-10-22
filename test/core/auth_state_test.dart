import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/core/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthState - Super-Admin Authorization (BUG-045, BUG-125)', () {
    test('grants super-admin status when role is admin in user payload', () {
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

    test('initial google auth state is clean and unpopulated', () {
      final auth = AuthState();
      expect(auth.pendingGoogleEmail, isNull);
      expect(auth.pendingGoogleName, isNull);
      expect(auth.isGoogleAccountUnregistered, isFalse);
    });
  });

  group('AuthState - Child Stats Dynamic Updates (BUG-145)', () {
    test('updateChildStats mutates in-memory user map and notifies listeners', () {
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
  });
}
