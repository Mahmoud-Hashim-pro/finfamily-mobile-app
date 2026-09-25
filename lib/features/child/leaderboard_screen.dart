import 'package:flutter/material.dart';
import '../../config/theme.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> rankings = [
      {
        'rank': 1,
        'name': 'لطفي (أنت)',
        'avatar': '👦',
        'xp': 1250,
        'level': 3,
        'streak': 5,
        'isCurrent': true,
      },
      {
        'rank': 2,
        'name': 'سارة',
        'avatar': '👧',
        'xp': 980,
        'level': 2,
        'streak': 3,
        'isCurrent': false,
      },
      {
        'rank': 3,
        'name': 'عمر (ابن العم)',
        'avatar': '🧒',
        'xp': 640,
        'level': 1,
        'streak': 1,
        'isCurrent': false,
      },
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('لوحة شرف الأبطال 🏆'),
      ),
      body: SafeArea(
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
                    Text('🥇', style: TextStyle(fontSize: 48)),
                    SizedBox(height: 8),
                    Text(
                      'أنت في المركز الأول هذا الأسبوع! 🎉',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'استمر في إنجاز المهام والتحويش للحفاظ على صدارة العائلة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Expanded(
                child: ListView.separated(
                  itemCount: rankings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = rankings[index];
                    final isCurrent = item['isCurrent'] == true;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isCurrent ? AppTheme.gold : AppTheme.cardBorder,
                          width: isCurrent ? 2 : 1,
                        ),
                        boxShadow: isCurrent
                            ? [
                                BoxShadow(
                                  color: AppTheme.gold.withOpacity(0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            item['rank'] == 1
                                ? '🥇'
                                : item['rank'] == 2
                                    ? '🥈'
                                    : '🥉',
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 14),
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: AppTheme.navy.withOpacity(0.08),
                            child: Text(item['avatar'], style: const TextStyle(fontSize: 22)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isCurrent ? AppTheme.navy : AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  'المستوى ${item['level']} · ${item['streak']} أيام متتالية 🔥',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${item['xp']} XP',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppTheme.emeraldDark,
                              fontFamily: 'monospace',
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
    );
  }
}
