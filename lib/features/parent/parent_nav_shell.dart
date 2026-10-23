import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'parent_dashboard_screen.dart';
import 'allowance_screen.dart';
import 'approvals_screen.dart';
import 'parent_coach_screen.dart';
import 'family_members_screen.dart';
import '../../core/update_checker.dart';

class ParentNavShell extends StatefulWidget {
  const ParentNavShell({super.key});

  @override
  State<ParentNavShell> createState() => _ParentNavShellState();
}

class _ParentNavShellState extends State<ParentNavShell> {
  int _currentIndex = 0;
  final ValueNotifier<int> _dashboardRefreshSignal = ValueNotifier(0);
  // The other tabs also live in the IndexedStack (initState runs once), so each gets its own reload signal
  final ValueNotifier<int> _allowanceRefreshSignal = ValueNotifier(0);
  final ValueNotifier<int> _approvalsRefreshSignal = ValueNotifier(0);
  final ValueNotifier<int> _familyRefreshSignal = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    _dashboardRefreshSignal.dispose();
    _allowanceRefreshSignal.dispose();
    _approvalsRefreshSignal.dispose();
    _familyRefreshSignal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          ParentDashboardScreen(refreshSignal: _dashboardRefreshSignal),
          AllowanceScreen(refreshSignal: _allowanceRefreshSignal),
          ApprovalsScreen(refreshSignal: _approvalsRefreshSignal),
          const ParentCoachScreen(),
          FamilyMembersScreen(refreshSignal: _familyRefreshSignal),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                if (index != _currentIndex) {
                  if (index == 0) {
                    _dashboardRefreshSignal.value++;
                  } else if (index == 1) {
                    _allowanceRefreshSignal.value++;
                  } else if (index == 2) {
                    _approvalsRefreshSignal.value++;
                  } else if (index == 4) {
                    _familyRefreshSignal.value++;
                  }
                }
                setState(() => _currentIndex = index);
              },
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppTheme.navy,
              unselectedItemColor: AppTheme.textMuted,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.dashboard_outlined),
                  activeIcon: Icon(Icons.dashboard),
                  label: 'الرئيسية',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  activeIcon: Icon(Icons.account_balance_wallet),
                  label: 'المصروف',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.task_alt_outlined),
                  activeIcon: Icon(Icons.task_alt),
                  label: 'الموافقات',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.auto_awesome_outlined),
                  activeIcon: Icon(Icons.auto_awesome),
                  label: 'المستشار الذكي',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.group_outlined),
                  activeIcon: Icon(Icons.group),
                  label: 'العائلة',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
