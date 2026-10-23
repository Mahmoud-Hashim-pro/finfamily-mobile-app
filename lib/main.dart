import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'core/auth_state.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/role_select_screen.dart';

/// Root navigator: lets the app leave any parent/child/admin shell when the session is invalidated (C4).
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(
    MultiProvider(
      providers: [
        // Eager: session verification starts at launch and overlaps the splash delay
        ChangeNotifierProvider(create: (_) => AuthState(), lazy: false),
      ],
      child: const FinFamilyApp(),
    ),
  );
}

class FinFamilyApp extends StatefulWidget {
  /// First screen; defaults to the splash screen (overridable for tests).
  final Widget? home;

  const FinFamilyApp({super.key, this.home});

  @override
  State<FinFamilyApp> createState() => _FinFamilyAppState();
}

class _FinFamilyAppState extends State<FinFamilyApp> {
  AuthState? _auth;

  @override
  void initState() {
    super.initState();
    _auth = Provider.of<AuthState>(context, listen: false);
    _auth!.sessionExpired.addListener(_onSessionExpired);
  }

  @override
  void dispose() {
    _auth?.sessionExpired.removeListener(_onSessionExpired);
    super.dispose();
  }

  /// The backend invalidated the live session (expired / revoked token): return to the login root.
  void _onSessionExpired() {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      (route) => false,
    );
    rootScaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً'),
          backgroundColor: AppTheme.coral,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FinFamily',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootScaffoldMessengerKey,

      // Arabic Localization & RTL configuration
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [
        Locale('ar', 'EG'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      home: widget.home ?? const SplashScreen(),
    );
  }
}
