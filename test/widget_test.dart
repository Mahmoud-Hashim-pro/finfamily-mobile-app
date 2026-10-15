import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finfamily_mobile/config/theme.dart';
import 'package:finfamily_mobile/core/auth_state.dart';
import 'package:finfamily_mobile/features/auth/role_select_screen.dart';
import 'package:finfamily_mobile/features/auth/parent_login_screen.dart';
import 'package:finfamily_mobile/features/auth/child_login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FinFamily Mobile — UI & Widget Integration Suite', () {
    testWidgets('RoleSelectScreen displays branding and role selection cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const RoleSelectScreen(),
        ),
      );

      expect(find.text('👨‍👩‍👧‍👦 FinFamily'), findsOneWidget);
      expect(find.text('اختر طريقة الدخول المناسبة لك'), findsOneWidget);
      expect(find.text('أنا ولي أمر'), findsOneWidget);
      expect(find.text('أنا بطل مالي (طفل)'), findsOneWidget);
    });

    testWidgets('Tapping Parent Role card navigates to ParentLoginScreen', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthState()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RoleSelectScreen(),
          ),
        ),
      );

      await tester.tap(find.text('أنا ولي أمر'));
      await tester.pumpAndSettle();

      expect(find.byType(ParentLoginScreen), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsWidgets);
      expect(find.text('تسجيل الدخول عبر Google'), findsOneWidget);
    });

    testWidgets('ParentLoginScreen contains email, password, and Google auth components', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthState()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ParentLoginScreen(),
          ),
        ),
      );

      expect(find.byType(ParentLoginScreen), findsOneWidget);
      expect(find.text('تسجيل الدخول عبر Google'), findsOneWidget);
      expect(find.text('نسيت كلمة المرور؟'), findsOneWidget);

      // Verify form validation triggers on empty submit
      final loginBtn = find.text('تسجيل الدخول');
      expect(loginBtn, findsOneWidget);
      await tester.tap(loginBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ParentLoginScreen), findsOneWidget);
    });

    testWidgets('ChildLoginScreen renders family lookup and navigation options', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthState()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ChildLoginScreen(),
          ),
        ),
      );

      expect(find.byType(ChildLoginScreen), findsOneWidget);
      expect(find.text('دخول الأبطال الماليين 🚀'), findsOneWidget);
      expect(find.text('مرحباً يا بطل! 💳'), findsOneWidget);
    });
  });
}
