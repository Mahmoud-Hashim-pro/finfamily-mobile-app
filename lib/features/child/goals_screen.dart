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
    try {
      final res = await ApiClient().get('/wallet/me');
      final data = res.data;
      final rawGoals = (data['savings_goals'] as List?) ?? [];

      final List<GoalModel> loaded = rawGoals.map((g) {
        return GoalModel(
          id: g['id'] ?? '',
          name: g['name'] ?? '',
          target: (g['target'] as num?)?.toDouble() ?? 100.0,
          current: (g['current'] as num?)?.toDouble() ?? 0.0,
          icon: g['icon'] ?? '🎯',
          color: g['color'] ?? '#00B894',
          eta: 'قريباً',
          aiNote: 'استمر في التحويش لتحقيق هدفك!',
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
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('تحويش في "${_goals[index].name}"'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'المبلغ المراد إيداعه (ج.م)',
                  hintText: 'مثلاً: 20',
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
                      final val = double.tryParse(amountController.text.trim()) ?? 0.0;
                      if (val <= 0) {
                        setDialogState(() => dialogError = 'يرجى إدخال مبلغ صحيح');
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

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadGoals();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('عاش يا بطل! تم تحويش $val ج.م في هدفك 🚀'),
                            backgroundColor: AppTheme.emerald,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() {
                          isDepositing = false;
                          dialogError = ApiErrorHandler.getErrorMessage(e);
                        });
                      }
                    },
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
    );
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    String selectedIcon = '🎯';
    bool isSubmitting = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
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
              const Text(
                'إضافة هدف ادخار جديد 🎯',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navy),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['🚲', '🎮', '⚽', '🎒', '📱', '👟'].map((emoji) {
                  final isSelected = selectedIcon == emoji;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedIcon = emoji),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.emerald.withOpacity(0.2) : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.emerald : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: nameController,
                label: 'اسم الهدف الذي ترغب في شرائه',
                hint: 'مثلاً: حذاء رياضي',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: targetController,
                label: 'سعر الهدف بالجنيه',
                hint: '500',
                keyboardType: TextInputType.number,
              ),
              if (modalError != null) ...[
                const SizedBox(height: 8),
                Text(modalError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
              ],
              const SizedBox(height: 24),
              CustomButton(
                text: 'إنشاء الهدف والبدء في التحويش 🚀',
                backgroundColor: AppTheme.emerald,
                isLoading: isSubmitting,
                onPressed: () async {
                  final name = nameController.text.trim();
                  final target = double.tryParse(targetController.text.trim()) ?? 0.0;
                  if (name.isEmpty) {
                    setModalState(() => modalError = 'يرجى إدخال اسم الهدف');
                    return;
                  }
                  if (target <= 0) {
                    setModalState(() => modalError = 'يرجى إدخال مبلغ صحيح للهدف');
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
                        'color': '#00B894',
                      },
                    );

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    _loadGoals();

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم إنشاء هدف الادخار بنجاح! بالتوفيق يا بطل 🌟'),
                        backgroundColor: AppTheme.emerald,
                      ),
                    );
                  } catch (e) {
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
    );
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
                                        'تم جمع ${g.current.toStringAsFixed(1)} من ${g.target.toStringAsFixed(1)} ج.م',
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
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                    child: const Text('تحويش +', style: TextStyle(fontSize: 12)),
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
                                  'المتبقي: ${(g.target - g.current).clamp(0, double.infinity).toStringAsFixed(1)} ج.م',
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
