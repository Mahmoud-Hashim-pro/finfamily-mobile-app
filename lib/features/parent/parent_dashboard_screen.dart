import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_state.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../widgets/stat_card.dart';
import '../../core/error_handler.dart';
import 'family_cards_screen.dart';
import 'spending_limits_screen.dart';
import 'family_members_screen.dart';
import 'parent_mfa_settings_screen.dart';
import '../auth/role_select_screen.dart';
import '../admin/admin_dashboard_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({
    super.key,
    this.refreshSignal,
  });

  final ValueNotifier<int>? refreshSignal;

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _overview;
  List<dynamic> _children = [];
  List<dynamic> _transactions = [];

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_handleRefresh);
    _loadData();
  }

  void _handleRefresh() {
    _loadData();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRefresh);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await ApiClient().get(ApiConfig.familyOverview);
      final data = res.data;
      if (!mounted) return;
      setState(() {
        _overview = data;
        _children = data['children'] ?? [];
        _transactions = data['recent_transactions'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.navy,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.coral.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.coral.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.coral),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppTheme.coral, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('إعادة المحاولة', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                if (_isLoading && _overview == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: CircularProgressIndicator(color: AppTheme.navy),
                    ),
                  ),

                // Header: Profile & Family Code
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppTheme.navy.withOpacity(0.1),
                          child: const Text('👨', style: TextStyle(fontSize: 22)),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user?['full_name'] ?? 'ولي الأمر',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.navy,
                              ),
                            ),
                            Text(
                              _overview?['family_name'] ??
                                  (auth.user?['full_name'] != null
                                      ? 'عائلة ${auth.user!['full_name']}'
                                      : 'عائلتي'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.gold),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tag, size: 14, color: AppTheme.navy),
                              const SizedBox(width: 4),
                              Text(
                                _overview?['family_code'] ?? '---',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: AppTheme.navy,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.security, size: 20, color: AppTheme.navy),
                          tooltip: 'إعدادات الأمان (2FA)',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ParentMfaSettingsScreen()),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.logout, size: 20, color: AppTheme.coral),
                          tooltip: 'تسجيل الخروج',
                          onPressed: () async {
                            await auth.logout();
                            if (!context.mounted) return;
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RoleSelectScreen(),
                              ),
                              (route) => false,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                if (auth.isSuperAdmin) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminDashboardScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.gold, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.gold.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Text('👑', style: TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'لوحة الإدارة والرقابة العليا',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Super Admin',
                                      style: TextStyle(
                                        color: AppTheme.gold,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'متابعة أسطول الكروت، السيولة، ورادار الأمان',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: AppTheme.gold,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // Main Family Balance Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [AppTheme.navy, Color(0xFF1E3A8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.navy.withOpacity(0.3),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'إجمالي رصيد العائلة',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            ((_overview?['total_balance'] ?? 0.0) as num).toDouble().toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ج.م',
                            style: TextStyle(
                              color: AppTheme.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.trending_down,
                                size: 16, color: AppTheme.gold),
                            const SizedBox(width: 6),
                            Text(
                              'مصروف اليوم: ${((_overview?['total_spent_today'] ?? 0.0) as num).toDouble().toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Stat Cards Grid
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'الأبطال الماليين',
                        value: '${_children.length}',
                        icon: Icons.face,
                        iconColor: AppTheme.emerald,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: StatCard(
                        title: 'موافقات معلقة',
                        value: '${_overview?['pending_approvals_count'] ?? 0}',
                        icon: Icons.pending_actions,
                        iconColor: AppTheme.coral,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Children Cards & Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'كروت الأبناء ومصاريفهم',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FamilyCardsScreen(),
                          ),
                        );
                        _loadData();
                      },
                      child: const Text('إدارة الكروت'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Children List or Empty State
                if (_children.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.emerald.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_add_alt_1_outlined,
                              size: 36, color: AppTheme.emerald),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'لا يوجد أطفال مسجلون بعد',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'أضف أطفالك للبدء في تعيين كروت ميزة ومتابعة مصاريفهم ومهامهم',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FamilyMembersScreen(),
                              ),
                            );
                            _loadData();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إضافة بطل مالي جديد'),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _children.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final c = _children[index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.emerald.withOpacity(0.12),
                              ),
                              child: Center(
                                child: Text(c['avatar'] ?? '👦',
                                    style: const TextStyle(fontSize: 24)),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['full_name'] ?? 'ابن',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    c['card_number'] ?? '5061 •••• •••• 1234',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textMuted,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${(c['balance'] ?? 0.0).toStringAsFixed(1)} ج.م',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: AppTheme.emeraldDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const SpendingLimitsScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    'حدود الصرف ⚙️',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.navy,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 28),

                // Recent Transactions Feed
                const Text(
                  'أحدث معاملات العائلة',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 12),

                if (_transactions.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: const Text(
                      'لا توجد معاملات مسجلة حتى الآن',
                      style: TextStyle(color: AppTheme.textMuted),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final t = _transactions[index];
                      final isIncome = (t['amount'] as num?)?.toDouble() != null &&
                          (t['amount'] as num) > 0;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isIncome
                                      ? AppTheme.emerald.withOpacity(0.12)
                                      : AppTheme.coral.withOpacity(0.12),
                                  radius: 20,
                                  child: Icon(
                                    isIncome
                                        ? Icons.arrow_downward
                                        : Icons.shopping_bag_outlined,
                                    color: isIncome
                                        ? AppTheme.emerald
                                        : AppTheme.coral,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      t['merchant'] ?? 'مشتريات',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      '${t['child_name'] ?? 'ابن'} · ${t['date'] ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              '${(t['amount'] as num?)?.toDouble().toStringAsFixed(1)} ج.م',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: isIncome
                                    ? AppTheme.emeraldDark
                                    : AppTheme.coral,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
