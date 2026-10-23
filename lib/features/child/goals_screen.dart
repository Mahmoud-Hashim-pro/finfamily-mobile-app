import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import '../../models/mission_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<GoalModel> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get('/wallet/me');
      final data = res.data;
      final rawGoals = (data['savings_goals'] as List?) ?? [];

      final List<GoalModel> loaded = rawGoals.map((g) {
        final target = (g['target'] as num?)?.toDouble() ?? 100.0;
        final current = (g['current'] as num?)?.toDouble() ?? 0.0;
        final remaining = (target - current).clamp(0.0, double.infinity);
        final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

        final String eta;
        final String aiNote;
        if (current >= target) {
          eta = 'مكتمل بنجاح! 🏆';
          aiNote = 'مبروك يا بطل! حققت هدفك بالكامل وتقدر تستمتع بيه دلوقتي! 🎉';
        } else if (pct >= 0.75) {
          eta = 'خلال أسبوع تقريباً ⚡';
          aiNote = 'قربت جداً! باقي لك ${remaining.toStringAsFixed(2)} ج.م فقط لتحقيق الهدف!';
        } else if (pct >= 0.4) {
          eta = 'خلال 2-3 أسابيع ⏳';
          aiNote = 'ماشي بخطوات ممتازة! واصل إنجاز المهام لزيادة رصيدك.';
        } else {
          eta = 'خلال شهر تقريباً 🎯';
          aiNote = 'بداية رائعة! حوش جزء من مصروفك ومهامك اليومية عشان توصله أسرع.';
        }

        return GoalModel(
          id: (g['id'] ?? '').toString(),
          name: g['name'] ?? '',
          target: target,
          current: current,
          icon: g['icon'] ?? '🎯',
          color: g['color'] ?? '#00B894',
          eta: eta,
          aiNote: aiNote,
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _goals = loaded;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  void _depositToGoal(int index) {
    final amountController = TextEditingController();
    bool isDepositing = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          // No back/barrier dismissal while the deposit is in flight
          canPop: !isDepositing,
          child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تحويش في "${_goals[index].name}" 🎯', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ المراد إيداعه (ج.م)',
                  hintText: 'مثلاً: 20',
                  suffixText: 'ج.م',
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDepositing ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isDepositing
                  ? null
                  : () async {
                      final raw = normalizeArabicDigits(amountController.text.trim());
                      final val = double.tryParse(raw) ?? 0.0;
                      if (val <= 0) {
                        setDialogState(() => dialogError = 'يرجى إدخال مبلغ صحيح');
                        return;
                      }
                      if (val > 100000) {
                        setDialogState(() => dialogError = 'الحد الأقصى للإيداع هو 100,000 ج.م');
                        return;
                      }
                      // Backend rejects deposits above the goal's remaining amount (compare in piastres)
                      final goal = _goals[index];
                      final remaining = (goal.target - goal.current).clamp(0.0, double.infinity);
                      if ((val * 100).round() > (remaining * 100).round()) {
                        setDialogState(() => dialogError = 'المبلغ يتجاوز المتبقي للهدف (${remaining.toStringAsFixed(2)} ج.م)');
                        return;
                      }

                      setDialogState(() {
                        isDepositing = true;
                        dialogError = null;
                      });

                      try {
                        final g = _goals[index];
                        await ApiClient().post(
                          '/wallet/me/goals/${g.id}/deposit',
                          data: {'amount': val},
                        );

                        // Refresh the list even if the dialog was closed while the request was in flight
                        if (ctx.mounted && (ModalRoute.of(ctx)?.isCurrent ?? false)) Navigator.pop(ctx);
                        if (!mounted) return;
                        _loadGoals();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('عاش يا بطل! تم تحويش ${val.toStringAsFixed(2)} ج.م في هدفك 🚀'),
                            backgroundColor: AppTheme.emerald,
                          ),
                        );
                      } catch (e) {
                        if (!ctx.mounted) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ApiErrorHandler.getErrorMessage(e)), backgroundColor: AppTheme.coral),
                            );
                          }
                          return;
                        }
                        setDialogState(() {
                          isDepositing = false;
                          dialogError = ApiErrorHandler.getErrorMessage(e);
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
              child: isDepositing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('إيداع'),
            ),
          ],
          ),
        ),
      ),
    ).then((_) => amountController.dispose());
  }

  void _withdrawFromGoal(int index) {
    final amountController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;
    final g = _goals[index];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          // No back/barrier dismissal while the withdrawal is in flight
          canPop: !isSubmitting,
          child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('سحب من "${g.name}" ↩️', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الرصيد المتوفر في الهدف: ${g.current.toStringAsFixed(2)} ج.م',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ المراد سحبه (ج.م)',
                  hintText: 'مثلاً: 10',
                  suffixText: 'ج.م',
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final raw = normalizeArabicDigits(amountController.text.trim());
                      final val = double.tryParse(raw) ?? 0.0;
                      if (val <= 0 || (val * 100).round() > (g.current * 100).round()) {
                        setDialogState(() => dialogError = 'يرجى إدخال مبلغ صحيح لا يتجاوز ${g.current.toStringAsFixed(2)} ج.م');
                        return;
                      }

                      setDialogState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      try {
                        // Single withdraw call: its own error (e.g. not enough savings) is what the child sees
                        await ApiClient().post(
                          '/wallet/me/goals/${g.id}/withdraw',
                          data: {'amount': val},
                        );

                        // Refresh the list even if the dialog was closed while the request was in flight
                        if (ctx.mounted && (ModalRoute.of(ctx)?.isCurrent ?? false)) Navigator.pop(ctx);
                        if (!mounted) return;
                        _loadGoals();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم سحب ${val.toStringAsFixed(2)} ج.م من الهدف وإعادتها لكارت ميزة 💳'),
                            backgroundColor: AppTheme.navy,
                          ),
                        );
                      } catch (e) {
                        // The goal may be stale (or a timed-out withdraw may have gone through): reload it
                        if (mounted) _loadGoals();
                        if (!ctx.mounted) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(ApiErrorHandler.getErrorMessage(e)), backgroundColor: AppTheme.coral),
                            );
                          }
                          return;
                        }
                        setDialogState(() {
                          isSubmitting = false;
                          dialogError = ApiErrorHandler.getErrorMessage(e);
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('سحب للكارت'),
            ),
          ],
          ),
        ),
      ),
    ).then((_) => amountController.dispose());
  }

  void _deleteGoal(int index) {
    final g = _goals[index];
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          // No back/barrier dismissal while the delete is in flight
          canPop: !isDeleting,
          child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('حذف هدف الادخار 🗑️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Text(
            'هل أنت متأكد من حذف هدف "${g.name}"؟ سيتم استرداد أي رصيد محوش به تلقائياً إلى كارت ميزة الخاص بك.',
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);
                      try {
                        await ApiClient().delete('/wallet/me/goals/${g.id}');
                        // Refresh the list even if the dialog was closed while the request was in flight
                        if (ctx.mounted && (ModalRoute.of(ctx)?.isCurrent ?? false)) Navigator.pop(ctx);
                        if (!mounted) return;
                        _loadGoals();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم حذف هدف "${g.name}" بنجاح'),
                            backgroundColor: AppTheme.coral,
                          ),
                        );
                      } catch (e) {
                        if (ctx.mounted) setDialogState(() => isDeleting = false);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ApiErrorHandler.getErrorMessage(e)),
                            backgroundColor: AppTheme.coral,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coral),
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('تأكيد الحذف'),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    String selectedIcon = '🎯';
    bool isSubmitting = false;
    String? modalError;

    final icons = ['🎯', '🎮', '🚲', '👟', '📱', '🎧', '🛹', '📚', '👕', '⭐'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => PopScope(
          // No back/barrier dismissal while the goal is being created
          canPop: !isSubmitting,
          child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'تحديد هدف ادخار جديد 🎯',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.navy,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (modalError != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.coral.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(modalError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الهدف / ما ترغب بشرائه',
                  hintText: 'مثلاً: دراجة جديدة، سماعات رأس',
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: targetController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ المستهدف (ج.م)',
                  hintText: 'مثلاً: 350',
                  suffixText: 'ج.م',
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              const Text('اختر أيقونة الهدف:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: icons.map((ic) {
                    final isSel = selectedIcon == ic;
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedIcon = ic),
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.emerald.withOpacity(0.15) : AppTheme.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSel ? AppTheme.emerald : AppTheme.cardBorder, width: isSel ? 2 : 1),
                        ),
                        child: Text(ic, style: const TextStyle(fontSize: 22)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'إنشاء الهدف والبدء في التحويش 🚀',
                backgroundColor: AppTheme.emerald,
                isLoading: isSubmitting,
                onPressed: () async {
                  final name = nameController.text.trim();
                  final rawTarget = normalizeArabicDigits(targetController.text.trim());
                  final target = double.tryParse(rawTarget) ?? 0.0;

                  if (name.isEmpty) {
                    setModalState(() => modalError = 'اكتب اسم الشيء الذي تريد تحويش ثمنه');
                    return;
                  }
                  if (target <= 0) {
                    setModalState(() => modalError = 'أدخل المبلغ المستهدف بشكل صحيح');
                    return;
                  }
                  // Backend SavingsGoalCreate requires target >= 10
                  if (target < 10) {
                    setModalState(() => modalError = 'الحد الأدنى للهدف هو 10 ج.م');
                    return;
                  }
                  if (target > 1000000) {
                    setModalState(() => modalError = 'الحد الأقصى للهدف هو 1,000,000 ج.م');
                    return;
                  }

                  setModalState(() {
                    isSubmitting = true;
                    modalError = null;
                  });

                  try {
                    await ApiClient().post(
                      '/wallet/me/goals',
                      data: {
                        'name': name,
                        'target': target,
                        'icon': selectedIcon,
                      },
                    );

                    // Refresh the list even if the sheet was closed (e.g. dragged down) while the request was in flight
                    if (ctx.mounted && (ModalRoute.of(ctx)?.isCurrent ?? false)) Navigator.pop(ctx);
                    if (!mounted) return;
                    _loadGoals();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إنشاء هدف الادخار بنجاح! بالتوفيق يا بطل 🌟'),
                        backgroundColor: AppTheme.emerald,
                      ),
                    );
                  } catch (e) {
                    if (!ctx.mounted) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ApiErrorHandler.getErrorMessage(e)), backgroundColor: AppTheme.coral),
                        );
                      }
                      return;
                    }
                    setModalState(() {
                      isSubmitting = false;
                      modalError = ApiErrorHandler.getErrorMessage(e);
                    });
                  }
                },
              ),
            ],
          ),
          ),
        ),
      ),
    ).then((_) {
      nameController.dispose();
      targetController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('حصالة الأحلام والأهداف 🎯'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadGoals,
          color: AppTheme.emerald,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Banner with Add Goal Action
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2D52), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('💡', style: TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'نصيحة الكوتش الذكي:',
                              style: TextStyle(
                                color: AppTheme.gold,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'تقسيم الحلم الكبير لأهداف أسبوعية صغيرة يخليك توصله أسرع!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'أهدافي الحالية:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddGoalDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emerald,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('هدف جديد', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppTheme.emerald),
                    ),
                  )
                else if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
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
                          onPressed: _loadGoals,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_goals.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        const Text('🎯', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        const Text(
                          'ليس لديك أهداف ادخار حالياً',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'اضغط على "هدف جديد" وحدد ما ترغب بشرائه وابدأ التحويش!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _showAddGoalDialog,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                          child: const Text('إضافة أول هدف 🚀'),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _goals.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final g = _goals[index];
                      final progress = (g.current / g.target).clamp(0.0, 1.0);
                      final isComplete = g.current >= g.target;

                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isComplete ? AppTheme.emerald : AppTheme.cardBorder,
                            width: isComplete ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.emerald.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(g.icon, style: const TextStyle(fontSize: 26)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        g.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: AppTheme.navy,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'تم جمع ${g.current.toStringAsFixed(2)} من ${g.target.toStringAsFixed(2)} ج.م',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isComplete)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.emerald,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'مكتمل 🎉',
                                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                else
                                  ElevatedButton(
                                    onPressed: () => _depositToGoal(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.emerald,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    child: const Text('تحويش +', style: TextStyle(fontSize: 12)),
                                  ),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20, color: AppTheme.textMuted),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  onSelected: (val) {
                                    if (val == 'withdraw') {
                                      _withdrawFromGoal(index);
                                    } else if (val == 'delete') {
                                      _deleteGoal(index);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    PopupMenuItem(
                                      value: 'withdraw',
                                      enabled: g.current > 0,
                                      child: const Row(
                                        children: [
                                          Icon(Icons.arrow_back, size: 18, color: AppTheme.navy),
                                          SizedBox(width: 8),
                                          Text('سحب مبالغ للكارت ↩️', style: TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 18, color: AppTheme.coral),
                                          SizedBox(width: 8),
                                          Text('حذف الهدف 🗑️', style: TextStyle(fontSize: 12, color: AppTheme.coral)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  isComplete ? AppTheme.emerald : const Color(0xFF00B894),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'النسبة المكتملة: ${(progress * 100).toInt()}%',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                Text(
                                  'المتبقي: ${(g.target - g.current).clamp(0.0, double.infinity).toStringAsFixed(2)} ج.م',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
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
