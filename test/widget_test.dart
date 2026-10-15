import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:finfamily_mobile/main.dart';
import 'package:finfamily_mobile/core/auth_state.dart';

void main() {
  testWidgets('App initializes successfully with FinFamilyApp', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthState()),
        ],
        child: const FinFamilyApp(),
      ),
    );
    expect(find.byType(FinFamilyApp), findsOneWidget);
  });
}
