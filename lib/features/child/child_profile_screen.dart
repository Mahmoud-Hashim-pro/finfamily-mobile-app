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
  String? _errorMessage;
  Map<String, dynamic>? _walletData;
  List<dynamic> _missions = [];
  List<Map<String, dynamic>> _badges = [];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ApiClient();
      final auth = Provider.of<AuthState>(context, listen: false);
      final childId = auth.user?['id']?.toString() ?? '';

      final responses = await Future.wait([
        client.get(ApiConfig.walletMe),
        client.get(ApiConfig.missionsMine).catchError((_) => null as dynamic),
      ]);

      // Attempt to load badges dynamically from server (BUG-044)
      List<dynamic> rawBadges = [];
      try {
        final bRes = await client.get('/badges/mine');
        if (bRes.data is List) {
          rawBadges = bRes.data;
        } else if (bRes.data is Map && bRes.data['badges'] is List) {
          rawBadges = bRes.data['badges'];
        }
      } catch (_) {
        try {
          if (childId.isNotEmpty) {
            final bRes = await client.get('/api/family/children/$childId/badges');
            if (bRes.data is List) {
              rawBadges = bRes.data;
            } else if (bRes.data is Map && bRes.data['badges'] is List) {
              rawBadges = bRes.data['badges'];
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        if (responses[0].data != null) {
          _walletData = responses[0].data;
        }
        if (responses[1].data != null) {
          _missions = responses[1].data is List ? responses[1].data : [];
        }

        if (rawBadges.isNotEmpty) {
          _badges = rawBadges.map<Map<String, dynamic>>((b) {
            return {
              'id': b['id'] ?? '',
              'name': b['name'] ?? 'وسام',
              'icon': b['icon'] ?? '🏅',
              'earned': b['unlocked'] == true || b['earned'] == true,
              'desc': b['desc'] ?? b['description'] ?? '',
            };
          }).toList();
        } else {
          // Compute default badges based on user state
          final double savingsBalance = (_walletData?['savings_balance'] ?? 0.0).toDouble();
          final double totalBalance = (_walletData?['balance'] ?? 0.0).toDouble();
          final user = auth.user ?? {};
          final int level = user['level'] is int ? user['level'] : int.tryParse('${user['level']}') ?? 1;
          final int xp = user['xp'] is int ? user['xp'] : int.tryParse('${user['xp']}') ?? 0;
          final List<dynamic> goals = _walletData?['savings_goals'] ?? [];
          final int completedMissions = _missions.where((m) => m['status'] == 'completed' || m['status'] == 'approved').length;

          _badges = [
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
        }

        _isLoading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'تعذر تحميل بيانات المحفظة والملف الشخصي. يرجى التحقق من الاتصال وإعادة المحاولة.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final user = auth.user ?? {};

    final String name = user['full_name'] ?? user['name'] ?? 'البطل المالي';
    final String avatar = user['avatar'] ?? '👦';
    final int level = user['level'] is int ? user['level'] : int.tryParse('${user['level']}') ?? 1;
    final int xp = user['xp'] is int ? user['xp'] : int.tryParse('${user['xp']}') ?? 0;
    final int streak = user['streak'] is int ? user['streak'] : int.tryParse('${user['streak']}') ?? 1;

    final double savingsBalance = (_walletData?['savings_balance'] ?? 0.0).toDouble();
    final double totalBalance = (_walletData?['balance'] ?? 0.0).toDouble();
    final int financialScore = _walletData?['financial_score'] ?? 85;

    if (_isLoading && _walletData == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(title: const Text('الملف الشخصي للبطل 🌟')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null && _walletData == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundLight,
        appBar: AppBar(title: const Text('الملف الشخصي للبطل 🌟')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadProfileData,
                  icon: const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
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
                        child: Center(
                          child: Text(avatar, style: const TextStyle(fontSize: 42)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'المستوى $level 🏅',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.emeraldDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Stats Row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStat('نقاط الخبرة', '$xp XP', AppTheme.gold),
                            Container(width: 1, height: 28, color: AppTheme.cardBorder),
                            _buildStat('الحماسة المتتالية', '$streak أيام 🔥', AppTheme.coral),
                            Container(width: 1, height: 28, color: AppTheme.cardBorder),
                            _buildStat('الوعي المالي', '$financialScore%', AppTheme.emerald),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Financial Overview Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ملخص الأموال والادخار:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.navy,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.navy.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('رصيد الكارت المتاح', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${totalBalance.toStringAsFixed(1)} ج.م',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.emerald.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppTheme.emerald.withOpacity(0.2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('محفوظ في الأهداف', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${savingsBalance.toStringAsFixed(1)} ج.م',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: AppTheme.emeraldDark,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Badges & Achievements Section (BUG-044)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'أوسمة وإنجازات البطل 🏆',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    Text(
                      '${_badges.where((b) => b['earned'] == true).length}/${_badges.length} مفتوح',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.emeraldDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _badges.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                  ),
                  itemBuilder: (context, index) {
                    final b = _badges[index];
                    final bool isEarned = b['earned'] == true;

                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isEarned ? Colors.white : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isEarned ? AppTheme.gold.withOpacity(0.4) : AppTheme.cardBorder,
                          width: isEarned ? 1.5 : 1,
                        ),
                        boxShadow: isEarned
                            ? [
                                BoxShadow(
                                  color: AppTheme.gold.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isEarned ? (b['icon'] ?? '🏅') : '🔒',
                            style: TextStyle(
                              fontSize: 28,
                              color: isEarned ? null : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            b['name'] ?? '',
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
                            b['desc'] ?? '',
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
