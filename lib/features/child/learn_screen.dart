import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../core/auth_state.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _lessons = [
    {
      'id': 'les_1',
      'title': 'أساسيات المال والنقود',
      'icon': '🪙',
      'xp': 100,
      'status': 'completed',
      'desc': 'ما هو المال ولماذا نستخدمه في حياتنا اليومية؟',
      'content': 'النقود هي وسيلة للتبادل بدلاً من المقايضة القديمة. نستخدمها لشراء ما نحتاجه ولتحديد قيمة الأشياء، كما نستخدمها للادخار للمستقبل.',
    },
    {
      'id': 'les_2',
      'title': 'الاحتياجات مقابل الرغبات',
      'icon': '⚖️',
      'xp': 120,
      'status': 'in_progress',
      'desc': 'كيف تفرق بين ما تحتاجه للعيش وما تريده للتسلية.',
      'content': 'الاحتياجات هي الضروريات التي لا غنى عنها مثل الطعام، الشراب، المسكن، والعلاج. أما الرغبات فهي الأشياء الكمالية مثل الألعاب والحلوى الزائدة.',
    },
    {
      'id': 'les_3',
      'title': 'كيف تضع ميزانية لنفسك',
      'icon': '📊',
      'xp': 150,
      'status': 'locked',
      'desc': 'طريقة تقسيم مصروفك الأسبوعي بذكاء.',
      'content': 'الميزانية هي خطتك المالية. قسم مصروفك لقاعدة 50/30/20: 50% لاحتياجاتك، 30% لرغباتك، و20% ادخرها دائماً في حصالتك الذكية.',
    },
    {
      'id': 'les_4',
      'title': 'سحر الادخار والاستثمار',
      'icon': '🐷',
      'xp': 150,
      'status': 'locked',
      'desc': 'كيف تجعل الجنيهات القليلة تبني أحلامك الكبيرة.',
      'content': 'الادخار المنتظم هو بوابتك لتحقيق أهدافك الكبيرة لشراء ما تحلم به في المستقبل دون استدانة أو إحراج.',
    },
    {
      'id': 'les_5',
      'title': 'المدفوعات الرقمية وكارت ميزة',
      'icon': '💳',
      'xp': 140,
      'status': 'locked',
      'desc': 'كيف يعمل كارتك البنكي والدفع بدون تلامس.',
      'content': 'كارت ميزة يتيح لك الدفع الإلكتروني الآمن في المحلات وعبر الإنترنت بدون حمل نقود ورقية قد تضيع منك.',
    },
    {
      'id': 'les_6',
      'title': 'الأمان ومكافحة الاحتيال أونلاين',
      'icon': '🛡️',
      'xp': 160,
      'status': 'locked',
      'desc': 'حافظ على رقم الـ PIN السري ولا تشاركه مع أحد.',
      'content': 'رقمك السري PIN وكود الـ CVV خلف الكارت سريان تماماً! لا تخبر بهما أي شخص أو تشاركهما على الرسائل إطلاقاً.',
    },
  ];

  final List<Map<String, dynamic>> _games = [
    {
      'id': 'gm1',
      'title': 'محاكي التسوق الذكي (Shopping Simulator)',
      'icon': '🛒',
      'reward': '60 XP',
      'base_xp': 60,
      'color': AppTheme.navy,
      'desc': 'معاك ميزانية محددة.. اشترِ احتياجات العائلة دون تجاوز الميزانية.',
      'question': 'ميزانيتك 100 ج.م، وتريد شراء سلع ضرورية: حليب (30 ج) وخبز (20 ج) ولعبة (70 ج):',
      'optA': 'شراء الحليب والخبز فقط (50 ج.م) والادخار ✅',
      'optB': 'شراء اللعبة واستدانة الباقي ❌',
      'isCorrectA': true,
    },
    {
      'id': 'gm2',
      'title': 'تحدي الميزانية (Budget Challenge)',
      'icon': '📊',
      'reward': '70 XP',
      'base_xp': 70,
      'color': AppTheme.emerald,
      'desc': 'قسّم مصروفك الأسبوعي بذكاء بين الاحتياجات والادخار.',
      'question': 'أفضل قاعدة ذهبية لتقسيم المصروف الأسبوعي هي:',
      'optA': '50% احتياجات، 30% رغبات، 20% ادخار ✅',
      'optB': 'صرف 100% في أول يومين ❌',
      'isCorrectA': true,
    },
    {
      'id': 'gm3',
      'title': 'احتياج ولا رغبة؟ (Needs vs Wants)',
      'icon': '⚖️',
      'reward': '50 XP',
      'base_xp': 50,
      'color': AppTheme.gold,
      'desc': 'صنف العناصر بسرعة: هل هي أساسية للعيش أم كمالية؟',
      'question': 'شراء وجبة طعام صحية ومياه شرب يعتبر:',
      'optA': 'احتياج أساسي وضروري ✅',
      'optB': 'رغبة كمالية وترفيه ❌',
      'isCorrectA': true,
    },
    {
      'id': 'gm4',
      'title': 'تخمين الأسعار (Guess Price)',
      'icon': '🏷️',
      'reward': '40 XP',
      'base_xp': 40,
      'color': AppTheme.coral,
      'desc': 'خمن السعر الأقرب للمشتريات اليومية لتصبح متسوقاً واعياً.',
      'question': 'السعر التقريبي المنطقي لعلبة ألوان خشبية مدرسية جيدة:',
      'optA': 'حوالي 35 إلى 50 ج.م ✅',
      'optB': 'حوالي 500 ج.م ❌',
      'isCorrectA': true,
    },
    {
      'id': 'gm5',
      'title': 'صياد العملات (Coin Catcher)',
      'icon': '🪙',
      'reward': '55 XP',
      'base_xp': 55,
      'color': AppTheme.gold,
      'desc': 'اجمع العملات النقدية وتجنب فخاخ الصرف غير المبرر.',
      'question': 'إذا حصلت على عيدية 200 ج.م، التصرف الأذكى هو:',
      'optA': 'وضع جزء منها في حصالة هدفك والتمتع بالباقي ✅',
      'optB': 'شراء كل الحلوى في المحل دفعة واحدة ❌',
      'isCorrectA': true,
    },
    {
      'id': 'gm6',
      'title': 'تصنيف المصاريف (Expense Sorting)',
      'icon': '📑',
      'reward': '45 XP',
      'base_xp': 45,
      'color': AppTheme.blue,
      'desc': 'صنف النفقات بحسب أولويتها في الحياة اليومية.',
      'question': 'دفع فاتورة الكهرباء والإنترنت للمنزل يعتبر:',
      'optA': 'مصروف أساسي ملزم ✅',
      'optB': 'مصروف ترفيهي اختياري ❌',
      'isCorrectA': true,
    },
    {
      'id': 'gm7',
      'title': 'حساب الباقي (Change Maker)',
      'icon': '🧮',
      'reward': '65 XP',
      'base_xp': 65,
      'color': AppTheme.purple,
      'desc': 'احسب الباقي المستحق بدقة لتتأكد من استلام فلوسك كاملة.',
      'question': 'اشتريت بمبلغ 65 ج.م ودفعت للبائع ورقة فئة 100 ج.م، كم الباقي؟',
      'optA': '35 ج.م ✅',
      'optB': '25 ج.م ❌',
      'isCorrectA': true,
    },
    {
      'id': 'gm8',
      'title': 'المتسوق الذكي (Smart Shopper)',
      'icon': '🛍️',
      'reward': '50 XP',
      'base_xp': 50,
      'color': AppTheme.emerald,
      'desc': 'قارن بين العروض واشترِ السلعة ذات القيمة الحقيقية.',
      'question': 'عرض 2 بسعر 1 لمنتج لا تحتاجه وسينتهي تاريخه غداً:',
      'optA': 'تجنبه لأنه إهدار للمال دون فائدة ✅',
      'optB': 'اشترِه لأنه عليه تخفيض كبير ❌',
      'isCorrectA': true,
    },
    {
      'id': 'gm9',
      'title': 'محقق الاحتيال (Scam Detective)',
      'icon': '🕵️',
      'reward': '50 XP',
      'base_xp': 50,
      'color': AppTheme.coral,
      'desc': 'اكتشف الرسائل والمواقع المزيفة واحمي رقم PIN لكارتك.',
      'question': 'وصلتك رسالة "مبروك كسبت مليون جنيه! أرسل رقم كارت ميزة والـ PIN":',
      'optA': 'تجاهلها فوراً وأبلغ بابا أو ماما - محاولة احتيال! ✅',
      'optB': 'إرسال رقم الـ PIN فوراً للحصول على الجائزة ❌',
      'isCorrectA': true,
    },
    {
      'id': 'gm10',
      'title': 'المستثمر المستقبلي (Future Investor)',
      'icon': '📈',
      'reward': '60 XP',
      'base_xp': 60,
      'color': AppTheme.navy,
      'desc': 'افهم سحر نمو الأموال بالصبر والاستثمار طويل الأمد.',
      'question': 'الفائدة أو العائد الاستثماري على المدخرات يعني:',
      'optA': 'مكافأة مالية إضافية تُضاف لفلوسك لأنك ادخرتها بذكاء ✅',
      'optB': 'خصم بنكي يقلل من رصيدك ❌',
      'isCorrectA': true,
    },
    {
      'id': 'gm11',
      'title': 'بطل الادخار (Saving Hero)',
      'icon': '🐷',
      'reward': '50 XP',
      'base_xp': 50,
      'color': AppTheme.emerald,
      'desc': 'تحدى نفسك وادخر لشراء حلمك دون استعجال.',
      'question': 'إذا كنت تريد شراء دراجة بـ 1200 ج.م ومصروفك يسمح بادخار 100 ج شهرياً:',
      'optA': 'الصبر والادخار لمدة سنة للوصول للهدف بكل فخر ✅',
      'optB': 'الاستسلام وصرف الفلوس على أشياء صغيرة غير مفيدة ❌',
      'isCorrectA': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadLessonProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLessonProgress() async {
    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final childId = auth.user?['id']?.toString() ?? 'default';
      final prefs = await SharedPreferences.getInstance();
      List<String> completed = prefs.getStringList('completed_lessons_$childId') ?? ['les_1'];

      // Sync authoritative completed lessons from backend
      try {
        final res = await ApiClient().get('/lessons/completed');
        if (res.data is List) {
          final serverList = (res.data as List).map((e) => e.toString()).toList();
          for (var s in serverList) {
            if (!completed.contains(s)) completed.add(s);
          }
          await prefs.setStringList('completed_lessons_$childId', completed);
        }
      } catch (_) {
        // Fallback to local storage if offline
      }

      if (!mounted) return;
      setState(() {
        for (int i = 0; i < _lessons.length; i++) {
          final id = _lessons[i]['id'];
          if (completed.contains(id)) {
            _lessons[i]['status'] = 'completed';
          } else {
            final prevCompleted = i == 0 || completed.contains(_lessons[i - 1]['id']);
            _lessons[i]['status'] = prevCompleted ? 'in_progress' : 'locked';
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _completeLesson(Map<String, dynamic> lesson) async {
    final auth = Provider.of<AuthState>(context, listen: false);
    final childId = auth.user?['id']?.toString() ?? 'default';
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getStringList('completed_lessons_$childId') ?? ['les_1'];

    final id = lesson['id'] as String;
    final int xp = (lesson['xp'] as num?)?.toInt() ?? 20;

    // Send authoritative lesson completion to backend
    try {
      final res = await ApiClient().post(
        '/lessons/complete',
        data: {'lesson_id': id, 'xp': xp},
      );
      if (res.data != null && res.data is Map) {
        final int? newXp = (res.data['current_xp'] as num?)?.toInt();
        final int? newLevel = (res.data['current_level'] as num?)?.toInt();
        if (newXp != null) {
          auth.updateChildStats(xp: newXp, level: newLevel);
        }
      }
    } catch (_) {
      // Local fallback on transient error
    }

    if (!completed.contains(id)) {
      completed.add(id);
      await prefs.setStringList('completed_lessons_$childId', completed);
    }

    await _loadLessonProgress();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('مبروك! أتممت درس "${lesson['title']}" وحصلت على +$xp XP! 🎓'),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  void _openLesson(Map<String, dynamic> lesson) {
    final isLocked = lesson['status'] == 'locked';
    if (isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الدرس مغلق حالياً 🔒. أنجز الدروس السابقة أولاً لفتحه!'),
          backgroundColor: AppTheme.coral,
        ),
      );
      return;
    }

    final isDone = lesson['status'] == 'completed';

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Text(lesson['icon'] ?? '📖', style: const TextStyle(fontSize: 48))),
            const SizedBox(height: 12),
            Text(
              lesson['title'] ?? 'درس مالي',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navy),
            ),
            const SizedBox(height: 8),
            Text(
              lesson['desc'] ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Text(
                lesson['content'] ?? lesson['desc'] ?? '',
                style: const TextStyle(fontSize: 14, height: 1.6, color: AppTheme.textPrimary),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (!isDone) {
                  _completeLesson(lesson);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone ? Colors.grey.shade400 : AppTheme.emerald,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isDone ? 'تم إنهاء هذا الدرس مسبقاً ✅' : 'فهمت الدرس وأريد المكافأة 🎓 (+${lesson['xp']} XP)',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _playMiniGame(Map<String, dynamic> game) {
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(game['icon'], style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                game['title'],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navy),
              ),
              const SizedBox(height: 8),
              Text(
                game['desc'],
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'سؤال التحدي المالي:',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navy),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      game['question'] ?? 'ما هو القرار المالي الصحيح؟',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (isSubmitting)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppTheme.emerald),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          setSheetState(() => isSubmitting = true);
                          await _submitGameCompletion(ctx, game, isCorrect: true, selectedOption: 'optA');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          game['optA'] ?? 'خيار أ ✅',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('حاول مرة أخرى! راجع مبادئ الإدارة المالية الذكية 💡'),
                              backgroundColor: AppTheme.coral,
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          game['optB'] ?? 'خيار ب ❌',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitGameCompletion(BuildContext sheetContext, Map<String, dynamic> game, {required bool isCorrect, required String selectedOption}) async {
    try {
      final res = await ApiClient().post(
        '/games/complete',
        data: {
          'game_id': game['id'],
          'score': isCorrect ? 1.0 : 0.0,
          'total': 1.0,
          'selected_option': selectedOption,
        },
      );

      final data = res.data;
      final xpAwarded = data['xp_awarded'] ?? 0;
      final coinsAwarded = (data['coins_awarded'] as num?)?.toDouble() ?? 0.0;
      final bool already = data['already_rewarded_today'] == true;
      final bool leveledUp = data['leveled_up'] == true;
      final int? newXp = (data['new_xp'] as num?)?.toInt();
      final int? newLevel = (data['new_level'] as num?)?.toInt();
      final double? newBalance = (data['new_balance'] as num?)?.toDouble();
      final int? newStreak = (data['new_streak'] as num?)?.toInt();

      if (!mounted) return;
      final auth = Provider.of<AuthState>(context, listen: false);
      auth.updateChildStats(
        xp: newXp,
        level: newLevel,
        streak: newStreak,
        balance: newBalance,
      );

      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }

      if (!mounted) return;

      String message;
      if (already) {
        message = 'أحسنت! أتممت لعبة "${game['title']}". لقد حصلت على جائزة هذه اللعبة اليوم مسبقاً! 🌟';
      } else {
        message = 'إجابة صحيحة يا بطل! 🎉 حصلت على +$xpAwarded XP و +${coinsAwarded.toStringAsFixed(1)} ج.م كوينز!';
        if (leveledUp) {
          message += ' 🚀 مبروك الترقية للمستوى $newLevel!';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.emerald,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (sheetContext.mounted) {
        Navigator.pop(sheetContext);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorHandler.getErrorMessage(e)),
          backgroundColor: AppTheme.coral,
        ),
      );
    }
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

                return GestureDetector(
                  onTap: () => _openLesson(l),
                  child: Container(
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
