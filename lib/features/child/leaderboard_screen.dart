import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../core/auth_state.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _rankings = [];

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    if (mounted) {
      setState(() {
        _errorMessage = null;
        if (_rankings.isEmpty) _isLoading = true;
      });
    }
    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final currentUserId = auth.user?['id'];

      final res = await ApiClient().get('/auth/family/children');
      final kids = (res.data['children'] as List?) ?? [];

      // Sort by XP descending
      final sortedKids = List<Map<String, dynamic>>.from(kids);
      sortedKids.sort((a, b) {
        final xpA = (a['xp'] as num?)?.toInt() ?? 0;
        final xpB = (b['xp'] as num?)?.toInt() ?? 0;
        return xpB.compareTo(xpA);
      });

      final List<Map<String, dynamic>> loaded = [];
      for (int i = 0; i < sortedKids.length; i++) {
        final k = sortedKids[i];
        final isCurrent = k['id'] == currentUserId;
        loaded.add({
          'rank': i + 1,
          'name': isCurrent ? '${k['full_name']} (أنت)' : (k['full_name'] ?? 'بطل مالي'),
          'avatar': i == 0 ? '👑' : (i == 1 ? '🥈' : (i == 2 ? '🥉' : (k['avatar'] ?? k['avatar_url'] ?? '👦').toString())),
          'xp': (k['xp'] as num?)?.toInt() ?? 0,
          'level': (k['level'] as num?)?.toInt() ?? 1,
          'streak': (k['streak'] as num?)?.toInt() ?? 0,
          'isCurrent': isCurrent,
        });
      }

      if (!mounted) return;
      setState(() {
        _rankings = loaded;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Keep the last good list; the empty "first hero" state is only for a real empty family
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  /// Non-list states still need a scrollable so pull-to-refresh works.
  Widget _scrollableCenter(Widget child) {
    return LayoutBuilder(
      builder: (ctx, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('لوحة شرف الأبطال 🏆'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadLeaderboard,
          color: AppTheme.emerald,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                // Top Trophy Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2D52), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Column(
                    children: [
                      Text('🏆', style: TextStyle(fontSize: 42)),
                      SizedBox(height: 8),
                      Text(
                        'ترتيب أبطال العائلة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'كل ما تنجز مهام وتحوش أكتر، هتجمع نقاط XP وتتصدر المركز الأول!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (_isLoading)
                  Expanded(
                    child: _scrollableCenter(
                      const CircularProgressIndicator(color: AppTheme.emerald),
                    ),
                  )
                else if (_errorMessage != null && _rankings.isEmpty)
                  Expanded(
                    child: _scrollableCenter(
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 44, color: Colors.redAccent),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, color: AppTheme.navy, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _loadLeaderboard,
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('إعادة المحاولة'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.emerald,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (_rankings.isEmpty)
                  Expanded(
                    child: _scrollableCenter(
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('🌟', style: TextStyle(fontSize: 36)),
                            SizedBox(height: 8),
                            Text(
                              'أنت أول بطل مسجل في عائلتك!',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'أنجز المهام وجمّع النقاط لتتصدر القمة.',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _rankings.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final r = _rankings[index];
                        final bool isCurrent = r['isCurrent'] ?? false;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isCurrent ? AppTheme.emerald : AppTheme.cardBorder,
                              width: isCurrent ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isCurrent
                                    ? AppTheme.emerald.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: r['rank'] == 1
                                      ? AppTheme.gold
                                      : (r['rank'] == 2
                                          ? const Color(0xFFE2E8F0)
                                          : (r['rank'] == 3
                                              ? const Color(0xFFFED7AA)
                                              : Colors.grey.shade100)),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${r['rank']}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: r['rank'] == 1 ? AppTheme.navyDark : AppTheme.navy,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(r['avatar'], style: const TextStyle(fontSize: 24)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r['name'],
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isCurrent ? AppTheme.emeraldDark : AppTheme.navy,
                                      ),
                                    ),
                                    Text(
                                      'المستوى ${r['level']} · ${r['streak']} أيام متتالية 🔥',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.emerald.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${r['xp']} XP',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.emeraldDark,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
