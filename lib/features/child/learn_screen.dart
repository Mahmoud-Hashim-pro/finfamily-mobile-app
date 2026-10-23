import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../core/auth_state.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';

/// Lesson path statuses: a lesson is 'completed' if the server/local list has it, otherwise
/// 'in_progress' when it is the first lesson or the previous one is completed, else 'locked'.
@visibleForTesting
List<String> computeLessonStatuses(List<String> orderedIds, Iterable<String> completed) {
  final done = completed.toSet();
  return [
    for (int i = 0; i < orderedIds.length; i++)
      done.contains(orderedIds[i])
          ? 'completed'
          : ((i == 0 || done.contains(orderedIds[i - 1])) ? 'in_progress' : 'locked'),
  ];
}

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  // Lessons whose completion POST is still in flight (blocks double claims)
  final Set<String> _claimingLessonIds = {};

  final List<Map<String, dynamic>> _lessons = [
    {
      'id': 'les_1',
      'title': 'أساسيات المال والنقود',
      'icon': '🪙',
      'xp': 100,
      'status': 'in_progress',
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
      'optA': 'شراء الحليب والخبز فقط (50 ج.م) والادخار',
      'optB': 'شراء اللعبة واستدانة الباقي',
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
      'optA': '50% احتياجات، 30% رغبات، 20% ادخار',
      'optB': 'صرف 100% في أول يومين',
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
      'optA': 'احتياج أساسي وضروري',
      'optB': 'رغبة كمالية وترفيه',
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
      'optA': 'حوالي 35 إلى 50 ج.م',
      'optB': 'حوالي 500 ج.م',
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
      'optA': 'وضع جزء منها في حصالة هدفك والتمتع بالباقي',
      'optB': 'شراء كل الحلوى في المحل دفعة واحدة',
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
      'optA': 'مصروف أساسي ملزم',
      'optB': 'مصروف ترفيهي اختياري',
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
      'optA': '35 ج.م',
      'optB': '25 ج.م',
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
      'optA': 'تجنبه لأنه إهدار للمال دون فائدة',
      'optB': 'اشترِه لأنه عليه تخفيض كبير',
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
      'optA': 'تجاهلها فوراً وأبلغ بابا أو ماما - محاولة احتيال!',
      'optB': 'إرسال رقم الـ PIN فوراً للحصول على الجائزة',
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
      'optA': 'مكافأة مالية إضافية تُضاف لفلوسك لأنك ادخرتها بذكاء',
      'optB': 'خصم بنكي يقلل من رصيدك',
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
      'optA': 'الصبر والادخار لمدة سنة للوصول للهدف بكل فخر',
      'optB': 'الاستسلام وصرف الفلوس على أشياء صغيرة غير مفيدة',
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

  /// Real child id for the per-child progress cache. Never falls back to a shared key:
  /// if /auth/me has not loaded yet, try once more, otherwise skip local caching.
  Future<String?> _resolveChildId(AuthState auth) async {
    var id = auth.user?['id']?.toString();
    if (id == null || id.isEmpty) {
      await auth.refreshCurrentUser();
      id = auth.user?['id']?.toString();
    }
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<void> _loadLessonProgress() async {
    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final prefs = await SharedPreferences.getInstance();
      // Purge the legacy shared cache that leaked progress between children
      await prefs.remove('completed_lessons_default');
      final childId = await _resolveChildId(auth);
      final cacheKey = childId == null ? null : 'completed_lessons_$childId';
      List<String> completed = (cacheKey == null ? null : prefs.getStringList(cacheKey)) ?? <String>[];

      // Server list is authoritative: replace the local cache with it (no merge)
      try {
        final res = await ApiClient().get('/lessons/completed');
        if (res.data is List) {
          completed = (res.data as List).map((e) => e.toString()).toList();
          if (cacheKey != null) {
            await prefs.setStringList(cacheKey, completed);
          }
        }
      } catch (_) {
        // Fallback to local storage if offline
      }

      if (!mounted) return;
      setState(() {
        final statuses = computeLessonStatuses(
          _lessons.map((l) => l['id'] as String).toList(),
          completed,
        );
        for (int i = 0; i < _lessons.length; i++) {
          _lessons[i]['status'] = statuses[i];
        }
      });
    } catch (_) {}
  }

  Future<void> _completeLesson(Map<String, dynamic> lesson) async {
    final id = lesson['id'] as String;
    // In-flight guard: a reopened sheet / second tap must not claim the same lesson twice
    if (_claimingLessonIds.contains(id)) return;
    setState(() => _claimingLessonIds.add(id));

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final int clientXp = (lesson['xp'] as num?)?.toInt() ?? 20;
      int awardedXp = clientXp;
      bool alreadyCompleted = false;

      // Send authoritative lesson completion to backend (FF-17: fail-closed on backend rejection)
      try {
        final res = await ApiClient().post(
          '/lessons/complete',
          data: {'lesson_id': id, 'xp': clientXp},
        );
        if (res.data != null && res.data is Map) {
          alreadyCompleted = res.data['already_completed'] == true;
          final int? newXp = (res.data['current_xp'] as num?)?.toInt();
          final int? newLevel = (res.data['current_level'] as num?)?.toInt();
          final int? serverAwarded = (res.data['xp_awarded'] as num?)?.toInt();
          if (serverAwarded != null) {
            awardedXp = serverAwarded;
          }
          if (newXp != null && !alreadyCompleted) {
            auth.updateChildStats(xp: newXp, level: newLevel);
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذر تسجيل إتمام الدرس. يرجى التحقق من الاتصال بالإنترنت والمحاولة مجدداً.'),
            backgroundColor: AppTheme.coral,
          ),
        );
        return;
      }

      // The server now has this lesson as completed (newly or already)
      final childId = await _resolveChildId(auth);
      if (childId != null) {
        final prefs = await SharedPreferences.getInstance();
        final cacheKey = 'completed_lessons_$childId';
        final completed = prefs.getStringList(cacheKey) ?? <String>[];
        if (!completed.contains(id)) {
          completed.add(id);
          await prefs.setStringList(cacheKey, completed);
        }
      }

      await _loadLessonProgress();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        alreadyCompleted
            ? SnackBar(
                content: Text('لقد أتممت درس "${lesson['title']}" مسبقاً'),
                backgroundColor: AppTheme.navy,
              )
            : SnackBar(
                content: Text('مبروك! أتممت درس "${lesson['title']}" وحصلت على +$awardedXp XP! 🎓'),
                backgroundColor: AppTheme.emerald,
              ),
      );
    } finally {
      if (mounted) setState(() => _claimingLessonIds.remove(id));
    }
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
    if (_claimingLessonIds.contains(lesson['id'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري تسجيل الدرس... ⏳')),
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
                if (!isDone && !_claimingLessonIds.contains(lesson['id'])) {
                  _completeLesson(lesson);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone ? Colors.grey.shade400 : AppTheme.emerald,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                isDone ? 'تم إنهاء هذا الدرس مسبقاً' : 'فهمت الدرس وأريد المكافأة 🎓 (+${lesson['xp']} XP)',
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
        builder: (ctx, setSheetState) => PopScope(
          canPop: !isSubmitting,
          child: Padding(
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
                  child: CircularProgressIndicator(color: AppTheme.navy),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          setSheetState(() => isSubmitting = true);
                          await _submitGameCompletion(ctx, game, isCorrect: true, selectedOption: 'optA');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navy,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          game['optA'] ?? 'الخيار (أ)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          setSheetState(() => isSubmitting = true);
                          await _submitGameCompletion(ctx, game, isCorrect: false, selectedOption: 'optB');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navy,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          game['optB'] ?? 'الخيار (ب)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
            ],
          ),
        )),
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

      if (sheetContext.mounted && Navigator.of(sheetContext).canPop()) {
        Navigator.pop(sheetContext);
      }

      if (!mounted) return;

      String message;
      Color snackColor = AppTheme.emerald;
      if (!isCorrect || (xpAwarded == 0 && !already)) {
        message = 'إجابة غير صحيحة، راجع السؤال وحاول مرة أخرى! 💡';
        snackColor = AppTheme.coral;
      } else if (already) {
        message = 'أحسنت! أتممت لعبة "${game['title']}". لقد حصلت على جائزة هذه اللعبة اليوم مسبقاً! 🌟';
      } else {
        message = 'إجابة صحيحة يا بطل! 🎉 حصلت على +$xpAwarded XP و +${coinsAwarded.toStringAsFixed(2)} ج.م كوينز!';
        if (leveledUp) {
          message += ' 🚀 مبروك الترقية للمستوى $newLevel!';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: snackColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (sheetContext.mounted && Navigator.of(sheetContext).canPop()) {
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
                      else if (_claimingLessonIds.contains(l['id']))
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.emerald),
                        )
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
