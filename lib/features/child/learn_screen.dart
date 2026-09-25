import 'package:flutter/material.dart';
import '../../config/theme.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _lessons = [
    {
      'title': 'أساسيات المال والنقود',
      'icon': '🪙',
      'xp': 100,
      'status': 'completed',
      'desc': 'ما هو المال ولماذا نستخدمه في حياتنا اليومية؟',
    },
    {
      'title': 'الاحتياجات مقابل الرغبات',
      'icon': '⚖️',
      'xp': 120,
      'status': 'completed',
      'desc': 'كيف تفرق بين ما تحتاجه للعيش وما تريده للتسلية.',
    },
    {
      'title': 'كيف تضع ميزانية لنفسك',
      'icon': '📊',
      'xp': 150,
      'status': 'in_progress',
      'desc': 'طريقة تقسيم مصروفك الأسبوعي بذكاء.',
    },
    {
      'title': 'سحر الادخار والاستثمار',
      'icon': '🐷',
      'xp': 150,
      'status': 'locked',
      'desc': 'كيف تجعل الجنيهات القليلة تبني أحلامك الكبيرة.',
    },
    {
      'title': 'المدفوعات الرقمية وكارت ميزة',
      'icon': '💳',
      'xp': 140,
      'status': 'locked',
      'desc': 'كيف يعمل كارتك البنكي والدفع بدون تلامس.',
    },
    {
      'title': 'الأمان ومكافحة الاحتيال أونلاين',
      'icon': '🛡️',
      'xp': 160,
      'status': 'locked',
      'desc': 'حافظ على رقم الـ PIN السري ولا تشاركه مع أحد.',
    },
  ];

  final List<Map<String, dynamic>> _games = [
    {
      'id': 'g1',
      'title': 'احتياج ولا رغبة؟ (Needs vs Wants)',
      'icon': '⚖️',
      'reward': '60 XP',
      'color': AppTheme.gold,
      'desc': 'صنف العناصر بسرعة: هل هي أساسية أم كمالية؟',
    },
    {
      'id': 'g2',
      'title': 'تخمين الأسعار (Guess the Price)',
      'icon': '🏷️',
      'reward': '50 XP',
      'color': AppTheme.emerald,
      'desc': 'خمن السعر الأقرب للمشتريات اليومية واكسب كوينز.',
    },
    {
      'id': 'g3',
      'title': 'محاكي التسوق الذكي',
      'icon': '🛒',
      'reward': '70 XP',
      'color': AppTheme.navy,
      'desc': 'معاك ميزانية 100 جنيه.. اشترِ احتياجات العائلة بدون ما تتخطاها.',
    },
    {
      'id': 'g4',
      'title': 'محقق الاحتيال (Scam Detective)',
      'icon': '🕵️',
      'reward': '80 XP',
      'color': AppTheme.coral,
      'desc': 'اكتشف الرسائل المزيفة واحمي فلوسك.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _playMiniGame(Map<String, dynamic> game) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(game['icon'], style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              game['title'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navy),
            ),
            const SizedBox(height: 8),
            Text(
              game['desc'],
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Text(
                    'السؤال 1 من 3:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'شراء كتاب دراسي للمدرسة يعتبر:',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('إجابة صحيحة! أحسنت يا بطل +${game['reward']} 🎉'),
                          backgroundColor: AppTheme.emerald,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emerald,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('احتياج ضروري ✅'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('حاول مرة أخرى! الكتب الدراسية من الاحتياجات الضرورية.'),
                          backgroundColor: AppTheme.coral,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('رغبة ترفيهية ❌'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('التعلم والألعاب المالية 🎮'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.navy,
          indicatorColor: AppTheme.navy,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(icon: Icon(Icons.school_outlined), text: 'الدروس والمسار'),
            Tab(icon: Icon(Icons.sports_esports_outlined), text: 'الألعاب والتحديات'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Lessons Tab
            ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _lessons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final l = _lessons[index];
                final isDone = l['status'] == 'completed';
                final isLocked = l['status'] == 'locked';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDone ? AppTheme.emerald.withOpacity(0.5) : AppTheme.cardBorder,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isLocked
                              ? Colors.grey.shade100
                              : AppTheme.navy.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            isLocked ? '🔒' : l['icon'],
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l['title'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isLocked ? AppTheme.textMuted : AppTheme.navy,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              l['desc'],
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isDone)
                        const Icon(Icons.check_circle, color: AppTheme.emerald, size: 22)
                      else if (!isLocked)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.gold.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${l['xp']} XP',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.navy,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),

            // Games Tab
            ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              itemCount: _games.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final g = _games[index];
                return GestureDetector(
                  onTap: () => _playMiniGame(g),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: (g['color'] as Color).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(g['icon'], style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g['title'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: AppTheme.navy,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                g['desc'],
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _playMiniGame(g),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: const Text('العب 🎮', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
