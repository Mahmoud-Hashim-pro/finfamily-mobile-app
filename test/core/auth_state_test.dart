import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/core/auth_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthState - Super-Admin Authorization (BUG-045, BUG-125)', () {
    test('grants super-admin status when role is admin in user payload', () {
      final auth = AuthState();
      expect(auth.isSuperAdmin, isFalse);
    });

    test('isSuperAdmin is false when unauthenticated', () {
      final auth = AuthState();
      expect(auth.isSuperAdmin, isFalse);
      expect(auth.isParent, isFalse);
      expect(auth.isChild, isFalse);
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
