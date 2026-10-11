import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_state.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../core/api_client.dart';
import '../auth/role_select_screen.dart';

class ChildProfileScreen extends StatefulWidget {
  const ChildProfileScreen({super.key});

  @override
  State<ChildProfileScreen> createState() => _ChildProfileScreenState();
}

class _ChildProfileScreenState extends State<ChildProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _walletData;
  List<dynamic> _missions = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final client = ApiClient();
      final responses = await Future.wait([
        client.get(ApiConfig.walletMe).catchError((_) => null as dynamic),
        client.get(ApiConfig.missionsMine).catchError((_) => null as dynamic),
      ]);

      if (mounted) {
        setState(() {
          if (responses[0] != null && responses[0].data != null) {
            _walletData = responses[0].data;
          }
          if (responses[1] != null && responses[1].data != null) {
            _missions = responses[1].data is List ? responses[1].data : [];
          }
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final user = auth.user ?? {};

    final String name = user['full_name'] ?? user['name'] ?? 'البطل المالي';
    final int level = user['level'] is int ? user['level'] : int.tryParse('${user['level']}') ?? 1;
    final int xp = user['xp'] is int ? user['xp'] : int.tryParse('${user['xp']}') ?? 0;
    final int streak = user['streak'] is int ? user['streak'] : int.tryParse('${user['streak']}') ?? 1;

    final double savingsBalance = (_walletData?['savings_balance'] ?? 0.0).toDouble();
    final double totalBalance = (_walletData?['balance'] ?? 0.0).toDouble();
    final int financialScore = _walletData?['financial_score'] ?? 85;
    final List<dynamic> goals = _walletData?['savings_goals'] ?? [];
    final int completedMissions = _missions.where((m) => m['status'] == 'completed' || m['status'] == 'approved').length;

    final List<Map<String, dynamic>> badges = [
      {
        'name': 'المدخر الذكي',
        'icon': '🐷',
        'earned': savingsBalance > 0 || totalBalance >= 50,
        'desc': 'بدأ الادخار وجمع رصيد إيجابي',
      },
      {
        'name': 'بطل الميزانية',
        'icon': '🛡️',
        'earned': (_walletData?['daily_limit'] ?? 0) > 0,
        'desc': 'يلتزم بحدود الصرف اليومية',
      },
      {
        'name': 'المستثمر الصغير',
        'icon': '📈',
        'earned': level >= 2 || xp >= 100,
        'desc': 'تخطى المستوى الأول وحصل خبرة',
      },
      {
        'name': 'قاهر الأهداف',
        'icon': '🎯',
        'earned': goals.isNotEmpty,
        'desc': 'أنشأ هدف ادخار في خطته',
      },
      {
        'name': 'بطل المهام',
        'icon': '🏅',
        'earned': completedMissions > 0,
        'desc': 'أنجز مهام بنجاح وحصل مكافآت',
      },
      {
        'name': 'حامي الكارت',
        'icon': '💳',
        'earned': _walletData?['card_status'] == 'active',
        'desc': 'يمتلك كارت ميزة مفعل وذكي',
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('الملف الشخصي للبطل 🌟'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProfileData,
            tooltip: 'تحديث البيانات',
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfileData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Avatar & Name Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.emerald.withOpacity(0.15),
                          border: Border.all(color: AppTheme.emerald, width: 3),
                        ),
                        child: const Center(
                          child: Text('👦', style: TextStyle(fontSize: 42)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المستوى $level · $xp XP نقطة خبرة',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.emeraldDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStat('الدرجة المالية', '$financialScore/100', Colors.amber.shade800),
                          Container(width: 1, height: 30, color: Colors.grey.shade200),
                          _buildStat('الأيام المتتالية', '$streak أيام 🔥', AppTheme.navy),
                          Container(width: 1, height: 30, color: Colors.grey.shade200),
                          _buildStat('المهام المنجزة', '$completedMissions مهام ✅', AppTheme.emeraldDark),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Badges Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'أوسمة الإنجازات (${badges.where((b) => b['earned'] == true).length}/${badges.length}) 🏅',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                    if (_isLoading)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Badges Grid
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: badges.length,
                  itemBuilder: (context, index) {
                    final b = badges[index];
                    final isEarned = b['earned'] == true;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isEarned ? Colors.white : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isEarned ? AppTheme.gold.withOpacity(0.5) : AppTheme.cardBorder,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isEarned ? b['icon'] : '🔒',
                            style: TextStyle(
                              fontSize: 28,
                              color: isEarned ? null : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            b['name'],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: isEarned ? AppTheme.navy : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            b['desc'],
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await auth.logout();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.coral),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.logout, color: AppTheme.coral),
                    label: const Text(
                      'تسجيل الخروج من الحساب',
                      style: TextStyle(
                        color: AppTheme.coral,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String title, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
