import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'child_home_screen.dart';
import 'meeza_card_screen.dart';
import 'wallet_screen.dart';
import 'learn_screen.dart';
import 'child_profile_screen.dart';
import '../../core/update_checker.dart';

class ChildNavShell extends StatefulWidget {
  const ChildNavShell({super.key});

  @override
  State<ChildNavShell> createState() => _ChildNavShellState();
}

class _ChildNavShellState extends State<ChildNavShell> {
  int _currentIndex = 0;

  // IndexedStack keeps every tab alive, so tabs showing wallet data refetch when reopened
  final ValueNotifier<int> _homeRefresh = ValueNotifier(0);
  final ValueNotifier<int> _meezaRefresh = ValueNotifier(0);
  final ValueNotifier<int> _walletRefresh = ValueNotifier(0);
  final ValueNotifier<int> _profileRefresh = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    _homeRefresh.dispose();
    _meezaRefresh.dispose();
    _walletRefresh.dispose();
    _profileRefresh.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (index != _currentIndex) {
      switch (index) {
        case 0:
          _homeRefresh.value++;
          break;
        case 1:
          _meezaRefresh.value++;
          break;
        case 2:
          _walletRefresh.value++;
          break;
        case 4:
          _profileRefresh.value++;
          break;
      }
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ChildHomeScreen(refreshSignal: _homeRefresh),
          MeezaCardScreen(refreshSignal: _meezaRefresh),
          WalletScreen(refreshSignal: _walletRefresh),
          const LearnScreen(),
          ChildProfileScreen(refreshSignal: _profileRefresh),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0B192C),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onTabSelected,
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.emerald,
              unselectedItemColor: Colors.white54,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'الرئيسية',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.credit_card_outlined),
                  activeIcon: Icon(Icons.credit_card),
                  label: 'كارت ميزة',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  activeIcon: Icon(Icons.account_balance_wallet),
                  label: 'المحفظة',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.sports_esports_outlined),
                  activeIcon: Icon(Icons.sports_esports),
                  label: 'تعلم والعب',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'حسابي',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
