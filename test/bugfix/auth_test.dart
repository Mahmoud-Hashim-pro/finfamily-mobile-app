import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finfamily_mobile/config/theme.dart';
import 'package:finfamily_mobile/core/auth_state.dart';
import 'package:finfamily_mobile/features/admin/admin_dashboard_screen.dart';
import 'package:finfamily_mobile/features/admin/admin_login_screen.dart';
import 'package:finfamily_mobile/features/auth/auth_input_utils.dart';
import 'package:finfamily_mobile/features/auth/mfa_screen.dart';
import 'package:finfamily_mobile/features/auth/parent_register_screen.dart';

/// AuthState double that records calls and never touches the network.
class _FakeAuthState extends AuthState {
  AuthStatus fakeStatus = AuthStatus.unauthenticated;
  String? fakeError;
  bool mfaPending = false;
  bool enrollment = false;
  String? secret;
  String? provisioningUri;
  List<String>? recoveryCodes;
  bool verifyResult = false;

  final List<String> calls = [];
  String? lastCode;

  @override
  AuthStatus get status => fakeStatus;
  @override
  String? get errorMessage => fakeError;
  @override
  bool get adminMfaPending => mfaPending;
  @override
  bool get adminMfaEnrollmentRequired => enrollment;
  @override
  String? get adminMfaSecret => secret;
  @override
  String? get adminMfaQrCode => null;
  @override
  String? get adminMfaProvisioningUri => provisioningUri;
  @override
  List<String>? get adminRecoveryCodes => recoveryCodes;

  @override
  Future<bool> loginAdmin(String email, String password) async {
    calls.add('loginAdmin');
    fakeStatus = AuthStatus.requiresMfa;
    mfaPending = true;
    notifyListeners();
    return false;
  }

  @override
  Future<bool> verifyAdminMfa(String code) async {
    calls.add('verifyAdminMfa');
    lastCode = code;
    if (!verifyResult) {
      fakeError = 'رمز التحقق غير صحيح';
      notifyListeners();
    }
    return verifyResult;
  }

  @override
  void cancelAdminMfa() {
    calls.add('cancelAdminMfa');
    mfaPending = false;
    fakeStatus = AuthStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void clearAdminRecoveryCodes() {
    calls.add('clearAdminRecoveryCodes');
    recoveryCodes = null;
  }

  @override
  Future<bool> verifyMfa(String code) async {
    calls.add('verifyMfa');
    lastCode = code;
    fakeError = 'رمز التحقق غير صحيح';
    return false;
  }

  @override
  Future<bool> loginParentWithRecovery(String recoveryCode, {String? email, String? password}) async {
    calls.add('loginParentWithRecovery');
    lastCode = recoveryCode;
    fakeError = 'كود الاستعادة غير صالح';
    return false;
  }
}

Widget _wrap(AuthState auth, Widget child) {
  return ChangeNotifierProvider<AuthState>.value(
    value: auth,
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

void _useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MO-AUTH #100 numeric codes (TOTP / PIN) accept Arabic-Indic digits', () {
    test('Arabic-Indic and Persian digits are normalized to ASCII', () {
      expect(normalizeNumericCode('١٢٣٤٥٦'), '123456');
      expect(normalizeNumericCode('۱۲۳۴۵۶'), '123456');
      expect(normalizeNumericCode(' 123 456 '), '123456');
      expect(isSixDigitCode(normalizeNumericCode('١٢٣٤٥٦')), isTrue);
    });

    test('only exactly six ASCII digits are valid (signs rejected)', () {
      expect(isSixDigitCode('123456'), isTrue);
      expect(isSixDigitCode('-12345'), isFalse);
      expect(isSixDigitCode('+12345'), isFalse);
      expect(isSixDigitCode('12345'), isFalse);
      expect(isSixDigitCode('1234567'), isFalse);
      expect(isSixDigitCode('12a456'), isFalse);
    });
  });

  group('MO-AUTH #30/#94 recovery codes use XXXX-XXXX-XXXX-XXXX (C1)', () {
    test('normalizes case, spaces and dashes', () {
      expect(normalizeRecoveryCode('hsg8-jwse-h982-hu8k'), 'HSG8JWSEH982HU8K');
      expect(normalizeRecoveryCode(' DQZF AE84-RZSA 4GVS '), 'DQZFAE84RZSA4GVS');
    });

    test('strips Unicode dashes auto-converted by notes / password apps', () {
      // en-dash, em-dash, non-breaking hyphen, minus sign
      expect(normalizeRecoveryCode('HSG8–JWSE–H982–HU8K'), 'HSG8JWSEH982HU8K');
      expect(normalizeRecoveryCode('hsg8—jwse‑h982−hu8k'), 'HSG8JWSEH982HU8K');
      expect(isValidRecoveryCode(normalizeRecoveryCode('HSG8–JWSE–H982–HU8K')), isTrue);
    });

    test('accepts 16-char backend codes and legacy 8-char codes only', () {
      expect(isValidRecoveryCode(normalizeRecoveryCode('HSG8-JWSE-H982-HU8K')), isTrue);
      expect(isValidRecoveryCode(normalizeRecoveryCode('ABCD-1234')), isTrue);
      expect(isValidRecoveryCode(normalizeRecoveryCode('ABCD-1234-XYZ')), isFalse);
      expect(isValidRecoveryCode(normalizeRecoveryCode('ABCD-1234-EFGH-567!')), isFalse);
      expect(isValidRecoveryCode(''), isFalse);
    });

    test('normalized 16-char code fits /auth/mfa/verify max_length=16', () {
      expect(normalizeRecoveryCode('6Q6C-9W37-MVVS-4SAA').length, 16);
    });
  });

  group('MO-AUTH #101 reset dialog accepts the code or the pasted link (C12)', () {
    test('raw token passes through unchanged (trimmed)', () {
      expect(extractResetToken('  AbC_def-123  '), 'AbC_def-123');
    });

    test('token is extracted from a pasted reset link', () {
      expect(
        extractResetToken('https://app.finfamily.app/reset-password?token=AbC_def-123'),
        'AbC_def-123',
      );
      expect(
        extractResetToken('http://localhost:5173/reset-password?token=Tok-9&utm=mail'),
        'Tok-9',
      );
    });

    test('token is extracted from a link pasted with surrounding text', () {
      expect(
        extractResetToken('الرابط: https://x.com/reset-password?token=Tok_42 شكراً'),
        'Tok_42',
      );
    });
  });

  group('MO-AUTH #106 / C9 child avatar on the login grid', () {
    test('reads avatar, then avatar_url, then the default emoji', () {
      expect(childAvatarOf({'avatar': '🦁', 'avatar_url': '🐼'}), '🦁');
      expect(childAvatarOf({'avatar': null, 'avatar_url': '🐼'}), '🐼');
      expect(childAvatarOf({'id': 'c1', 'full_name': 'Kid', 'avatar_url': null}), '👦');
      expect(childAvatarOf(null), '👦');
    });

    test('image URLs are never rendered as avatar text', () {
      expect(childAvatarOf({'avatar_url': 'https://cdn.example.com/a.png'}), '👦');
    });
  });

  group('MO-AUTH #2/#95/#3/#13/#204 admin dashboard reads real backend fields', () {
    test('card purchases render as 2-decimal debits', () {
      expect(AdminDashboardFormat.purchaseAmount(25.5), '-25.50 ج.م');
      expect(AdminDashboardFormat.purchaseAmount(30), '-30.00 ج.م');
      expect(AdminDashboardFormat.egp(null), '0.00');
      expect(AdminDashboardFormat.egp('12.5'), '12.50');
    });

    test('pending purchases are not labelled as rejected', () {
      final pending = AdminDashboardFormat.purchaseStatusLabel('pending');
      final rejected = AdminDashboardFormat.purchaseStatusLabel('rejected');
      final completed = AdminDashboardFormat.purchaseStatusLabel('completed');
      expect(pending, isNot(rejected));
      expect(pending, isNot(completed));
      expect(rejected, contains('مرفوضة'));
      expect(AdminDashboardFormat.purchaseStatusColor('pending'), AppTheme.gold);
    });

    test('null daily limit means no limit, not 100 EGP', () {
      expect(AdminDashboardFormat.dailyLimit(null), contains('بدون حد'));
      expect(AdminDashboardFormat.dailyLimit(null), isNot(contains('100')));
      expect(AdminDashboardFormat.dailyLimit(150), contains('150.00'));
    });

    test('audit / transaction dates come from created_at', () {
      expect(AdminDashboardFormat.datePart(null), '');
      // Naive UTC noon: the local date is the 10th (or the 11th east of UTC+12) in any device timezone
      expect(AdminDashboardFormat.datePart('2026-03-10T12:00:00'), matches(RegExp(r'^2026-03-1[01]$')));
    });

    test('DB health badge follows the backend status', () {
      expect(AdminDashboardFormat.isDbHealthy({'status': 'healthy', 'connection': 'healthy', 'latency_ms': 3.2}), isTrue);
      expect(AdminDashboardFormat.isDbHealthy({'status': 'unhealthy', 'connection': 'unhealthy', 'latency_ms': -1}), isFalse);
      expect(AdminDashboardFormat.isDbHealthy(null), isFalse);
    });
  });

  group('MO-AUTH #0 admin QR data URI', () {
    test('decodes the data URI returned by /admin/auth/login', () {
      expect(decodeQrDataUri('data:image/png;base64,iVBORw0KGgo='), isNotNull);
      expect(decodeQrDataUri(null), isNull);
      expect(decodeQrDataUri('data:image/png;base64,%%%'), isNull);
    });
  });

  group('MO-AUTH widgets', () {
    testWidgets('#0 admin login shows the mandatory MFA enrollment step and sends a normalized code',
        (WidgetTester tester) async {
      _useTallScreen(tester);
      final auth = _FakeAuthState()
        ..enrollment = true
        ..secret = 'JBSWY3DPEHPK3PXP'
        ..provisioningUri = 'otpauth://totp/FinFamily:admin@finfamily.com?secret=JBSWY3DPEHPK3PXP';

      await tester.pumpWidget(_wrap(auth, const AdminLoginScreen()));

      await tester.enterText(find.byType(TextField).at(0), 'admin@finfamily.com');
      await tester.enterText(find.byType(TextField).at(1), 'Secret123 ');
      await tester.tap(find.text('تسجيل الدخول كـ Super Admin 🛡️'));
      await tester.pumpAndSettle();

      // Password step never navigates on its own: the MFA step is shown instead
      expect(auth.calls, contains('loginAdmin'));
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
      expect(find.text('التحقق الإلزامي بخطوتين'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, '١٢٣٤٥٦');
      await tester.tap(find.text('تفعيل ودخول لوحة الإدارة 🛡️'));
      await tester.pumpAndSettle();

      expect(auth.lastCode, '123456');
      expect(find.text('رمز التحقق غير صحيح'), findsOneWidget);
      expect(find.byType(AdminDashboardScreen), findsNothing);

      // Back to the password step clears the pending challenge
      await tester.tap(find.text('رجوع لتسجيل الدخول'));
      await tester.pumpAndSettle();
      expect(auth.calls, contains('cancelAdminMfa'));
      expect(find.text('تسجيل الدخول كـ Super Admin 🛡️'), findsOneWidget);
    });

    testWidgets('#0 admin recovery codes are shown once after a successful enrollment',
        (WidgetTester tester) async {
      _useTallScreen(tester);
      final auth = _FakeAuthState()
        ..enrollment = true
        ..secret = 'JBSWY3DPEHPK3PXP'
        ..verifyResult = true
        ..recoveryCodes = ['AAAA-BBBB-CCCC-DDDD'];

      await tester.pumpWidget(_wrap(auth, const AdminLoginScreen()));
      await tester.enterText(find.byType(TextField).at(0), 'admin@finfamily.com');
      await tester.enterText(find.byType(TextField).at(1), 'Secret123');
      await tester.tap(find.text('تسجيل الدخول كـ Super Admin 🛡️'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '654321');
      await tester.tap(find.text('تفعيل ودخول لوحة الإدارة 🛡️'));
      // Bounded pumps: the MFA button keeps its indeterminate spinner behind the non-opaque
      // dialog until navigation, so pumpAndSettle would never settle here.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(auth.lastCode, '654321');
      expect(find.text('AAAA-BBBB-CCCC-DDDD'), findsOneWidget);
      expect(find.text('حفظتها، متابعة'), findsOneWidget);
      // Not navigated (and codes not discarded) until the admin confirms they were saved
      expect(find.byType(AdminDashboardScreen), findsNothing);
      expect(auth.calls, isNot(contains('clearAdminRecoveryCodes')));
    });

    testWidgets('#100 MFA screen sends Arabic-Indic TOTP digits as ASCII', (WidgetTester tester) async {
      _useTallScreen(tester);
      final auth = _FakeAuthState()..fakeStatus = AuthStatus.requiresMfa;

      await tester.pumpWidget(_wrap(auth, const MfaScreen()));
      await tester.enterText(find.byType(TextField).first, '١٢٣٤٥٦');
      await tester.tap(find.text('تأكيد ودخول'));
      await tester.pump();

      expect(auth.calls, contains('verifyMfa'));
      expect(auth.lastCode, '123456');

      // Let the error SnackBar expire so no timer is left pending
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('#30/#94/#107 recovery dialog accepts 16-char codes, normalizes them and stays open on error',
        (WidgetTester tester) async {
      _useTallScreen(tester);
      final auth = _FakeAuthState()..fakeStatus = AuthStatus.requiresMfa;

      await tester.pumpWidget(_wrap(auth, const MfaScreen()));
      await tester.tap(find.text('استخدام كود استعادة الطوارئ (Recovery Code)'));
      await tester.pumpAndSettle();

      final dialogField = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));

      // Wrong format: rejected locally, nothing sent
      await tester.enterText(dialogField, 'ABCD-1234-XY');
      await tester.tap(find.text('دخول بكود الاستعادة'));
      await tester.pumpAndSettle();
      expect(auth.calls, isNot(contains('loginParentWithRecovery')));
      expect(find.textContaining('صيغة كود الاستعادة غير صحيحة'), findsOneWidget);

      // Real backend format (lowercase, dashes, spaces) is normalized before sending
      await tester.enterText(dialogField, 'abcd-efgh 2345-6789');
      await tester.tap(find.text('دخول بكود الاستعادة'));
      await tester.pumpAndSettle();
      expect(auth.lastCode, 'ABCDEFGH23456789');

      // Failure keeps the dialog open with the server error, so the code can be corrected
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('كود الاستعادة غير صالح'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('#104 register screen interpolates the Google email and the family surname',
        (WidgetTester tester) async {
      _useTallScreen(tester);
      final auth = _FakeAuthState();

      await tester.pumpWidget(_wrap(
        auth,
        const ParentRegisterScreen(initialEmail: 'ahmed@example.com', initialName: 'Ahmed  Hassan'),
      ));

      expect(find.textContaining('(ahmed@example.com)'), findsOneWidget);
      expect(find.textContaining('()'), findsNothing);
      expect(find.text('عائلة Hassan'), findsOneWidget);
    });
  });
}
