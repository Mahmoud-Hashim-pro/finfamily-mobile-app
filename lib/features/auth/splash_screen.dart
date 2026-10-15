import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth_state.dart';
import '../../core/update_checker.dart';
import 'onboarding_screen.dart';
import 'role_select_screen.dart';
import '../parent/parent_nav_shell.dart';
import '../child/child_nav_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();

    // Set immersive edge-to-edge system bars with translucent dark styling
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF01102D),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // Smooth entry animation
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
    _startTransitionTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache the splash asset to guarantee immediate high-quality render without stutter
    precacheImage(const AssetImage('assets/images/splash.png'), context);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startTransitionTimer() async {
    // Show splash for 2.8 seconds so the user enjoys the official high-resolution branding
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted || _isNavigating) return;

    final auth = Provider.of<AuthState>(context, listen: false);

    // Await auth initialization with timeout so app NEVER navigates to login while auth is initializing
    try {
      await auth.authInitialized.timeout(const Duration(seconds: 4));
    } catch (_) {
      // Timeout reached: proceed with whatever auth status is available
    }

    if (!mounted || _isNavigating) return;
    _isNavigating = true;

    Widget nextScreen;
    if (auth.status == AuthStatus.authenticated) {
      nextScreen = auth.isParent ? const ParentNavShell() : const ChildNavShell();
    } else {
      bool onboardingDone = false;
      try {
        final prefs = await SharedPreferences.getInstance();
        onboardingDone = prefs.getBool('onboarding_completed') ?? false;
      } catch (_) {}

      if (onboardingDone) {
        nextScreen = const RoleSelectScreen();
      } else {
        nextScreen = const OnboardingScreen();
      }
    }

    if (!mounted) return;

    // Smooth cinematic fade transition into the app screen
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 700),
      ),
    ).then((_) {
      // Background check for updates after landing
      if (mounted) {
        UpdateChecker.checkForUpdates(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02102E),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF031944),
              Color(0xFF02102E),
              Color(0xFF01102D),
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Image.asset(
                  'assets/images/splash.png',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: const Center(
                              child: Text('👨‍👩‍👧‍👦', style: TextStyle(fontSize: 44)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'FinFamily',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
