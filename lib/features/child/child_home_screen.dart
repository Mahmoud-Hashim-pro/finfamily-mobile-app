import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../core/auth_state.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import '../../config/api_config.dart';
import 'missions_screen.dart';
import 'goals_screen.dart';
import 'child_coach_screen.dart';
import 'leaderboard_screen.dart';

class ChildHomeScreen extends StatefulWidget {
  const ChildHomeScreen({super.key, this.refreshSignal});

  /// Bumped by ChildNavShell when this tab is reopened, so the IndexedStack tab refetches.
  final ValueNotifier<int>? refreshSignal;

  @override
  State<ChildHomeScreen> createState() => _ChildHomeScreenState();
}

class _ChildHomeScreenState extends State<ChildHomeScreen> {
  double _balance = 0.0;
  String _cardNumber = '5061 •••• •••• 1234';
  int _activeMissionsCount = 0;
  String? _firstGoalName;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_handleRefresh);
    // checkAuth has just fetched /auth/me, so skip the duplicate user refresh on first load
    _loadData(refreshUser: false);
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRefresh);
    super.dispose();
  }

  void _handleRefresh() {
    _loadData();
  }

  Future<void> _loadData({bool refreshUser = true}) async {
    // Refresh level/XP/streak (server-side apply_xp / touch_streak) alongside the wallet fetch
    final Future<void> userRefresh = refreshUser
        ? Provider.of<AuthState>(context, listen: false).refreshCurrentUser()
        : Future<void>.value();

    try {
      final walletRes = await ApiClient().get('/wallet/me');
      final wallet = walletRes.data;

      // Optionally load the count of chores ready to do (status-filtered, so it is not capped by the
      // newest-50 page and does not count submitted items or redemption requests)
      int? missionsCount;
      try {
        final missionsRes = await ApiClient().get(
          ApiConfig.missionsMine,
          queryParameters: {'status': 'pending', 'limit': 100},
        );
        final mList = missionsRes.data as List? ?? [];
        missionsCount = mList.where((m) => (m['kind'] ?? 'chore') == 'chore' && m['status'] == 'pending').length;
      } catch (_) {}

      final goals = (wallet['savings_goals'] as List?) ?? [];

      if (!mounted) return;
      setState(() {
        _balance = (wallet['balance'] as num?)?.toDouble() ?? 0.0;
        _cardNumber = wallet['card_number'] ?? '5061 •••• •••• 1234';
        // Keep the previous count if only the missions request failed
        if (missionsCount != null) _activeMissionsCount = missionsCount;
        // Clear the name when the last goal was deleted
        _firstGoalName = goals.isNotEmpty ? goals.first['name']?.toString() : null;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
    // refreshCurrentUser never throws (keeps the old state on failure)
    await userRefresh;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);
    final childName = auth.user?['full_name'] ?? 'بطل مالي';
    final String avatar = (auth.user?['avatar'] ?? auth.user?['avatar_url'] ?? '👦').toString();
    final int level = (auth.user?['level'] as num?)?.toInt() ?? 1;
    final int xp = (auth.user?['xp'] as num?)?.toInt() ?? 0;
    final int streak = (auth.user?['streak'] as num?)?.toInt() ?? 0;

    // Backend LEVEL_THRESHOLDS = [(1, 0), (2, 400), (3, 900), (4, 1600), (5, 2500), (6, 3600), (7, 5000), (8, 7000)]
    const thresholds = [0, 400, 900, 1600, 2500, 3600, 5000, 7000];
    int currentFloor = 0;
    int nextCeiling = 400;
    if (level >= 1 && level <= thresholds.length) {
      currentFloor = thresholds[level - 1];
      if (level < thresholds.length) {
        nextCeiling = thresholds[level];
      } else {
        nextCeiling = currentFloor + 2500;
      }
    } else {
      currentFloor = (level - 1) * 1000;
      nextCeiling = level * 1000;
    }
    final int range = nextCeiling - currentFloor;
    final double xpProgress = range > 0 ? ((xp - currentFloor) / range).clamp(0.0, 1.0) : 1.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.emerald,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Avatar, Name & Streaks
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.emerald.withOpacity(0.15),
                              border: Border.all(color: AppTheme.emerald, width: 2),
                            ),
                            child: Center(
                              child: Text(avatar, style: const TextStyle(fontSize: 28)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'صباح الخير يا بطل! 🚀',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  childName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.navy,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Streak badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.gold),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 16)),
                          const SizedBox(width: 4),
                          Text(
                            '$streak أيام متتالية',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Error message if any (BUG-089)
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
                        const Icon(Icons.error_outline, color: AppTheme.coral, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppTheme.coral, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh, size: 16, color: AppTheme.coral),
                          label: const Text('إعادة المحاولة', style: TextStyle(color: AppTheme.coral, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),

                // Level & XP Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2D52), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.navy.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 18)),
                              const SizedBox(width: 6),
                              Text(
                                'المستوى $level · بطل التوفير',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$xp / $nextCeiling XP',
                            style: const TextStyle(
                              color: AppTheme.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: xpProgress,
                          minHeight: 8,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Quick Balance & Card Preview
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00B894), Color(0xFF059669)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emerald.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'رصيد كارت ميزة المتاح',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.gold,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'meeza',
                              style: TextStyle(
                                color: AppTheme.navyDark,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            _balance.toStringAsFixed(2),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'ج.م',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _cardNumber,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          letterSpacing: 2,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Quick Actions Grid
                Row(
                  children: [
                    _QuickAction(
                      emoji: '🧹',
                      title: 'المهام والفلوس',
                      subtitle: _activeMissionsCount > 0
                          ? '$_activeMissionsCount مهمات جاهزة'
                          : 'عرض مهامك المالية',
                      color: AppTheme.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MissionsScreen()),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      emoji: '🎯',
                      title: 'حصالة الأحلام',
                      subtitle: _firstGoalName != null ? _firstGoalName! : 'أهداف الادخار 🚲',
                      color: AppTheme.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GoalsScreen()),
                        ).then((_) => _loadData());
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _QuickAction(
                      emoji: '🤖',
                      title: 'صديقي المالي',
                      subtitle: 'اسأل الذكاء الاصطناعي',
                      color: AppTheme.emerald,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChildCoachScreen()),
                        );
                      },
                    ),
                    const SizedBox(width: 12),
                    _QuickAction(
                      emoji: '🏆',
                      title: 'لوحة الأبطال',
                      subtitle: 'ترتيب العائلة 🥇',
                      color: AppTheme.gold,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Daily Challenge
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.gold.withOpacity(0.5)),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.gold.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text('⚡', style: TextStyle(fontSize: 26)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تحدي اليوم: وفّر 10 جنيه',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppTheme.navy,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'وفّر ثمن سناك واحد وحطه في هدفك لتحصل على 50 XP!',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
}

class _QuickAction extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
