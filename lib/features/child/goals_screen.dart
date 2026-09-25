import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/mission_model.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final List<GoalModel> _goals = [
    GoalModel(
      id: 'g1',
      name: 'عجلة جديدة للشارع',
      target: 1200.0,
      current: 480.0,
      icon: '🚲',
      color: '#00B894',
      eta: '8 أسابيع',
      aiNote: 'وفّر 40 ج.م في الأسبوع عشان تخلص أسرع بأسبوعين!',
    ),
    GoalModel(
      id: 'g2',
      name: 'لعبة بلايستيشن جديدة',
      target: 350.0,
      current: 210.0,
      icon: '🎮',
      color: '#FFC857',
      eta: '3 أسابيع',
      aiNote: 'ماشي في المسار الصح.. استمرارية عظيمة!',
    ),
    GoalModel(
      id: 'g3',
      name: 'كورة قدم أصلية',
      target: 200.0,
      current: 95.0,
      icon: '⚽',
      color: '#3B82F6',
      eta: '5 أسابيع',
      aiNote: 'حوش 5 جنيه كل يوم وهتشتريها قريب جداً.',
    ),
  ];

  void _depositToGoal(int index) {
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تحويش في "${_goals[index].name}"'),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'المبلغ المراد إيداعه (ج.م)',
            hintText: 'مثلاً: 20',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(amountController.text.trim()) ?? 0.0;
              if (val > 0) {
                setState(() {
                  final g = _goals[index];
                  _goals[index] = GoalModel(
                    id: g.id,
                    name: g.name,
                    target: g.target,
                    current: (g.current + val).clamp(0.0, g.target),
                    icon: g.icon,
                    color: g.color,
                    eta: g.eta,
                    aiNote: g.aiNote,
                  );
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('عاش يا بطل! تم تحويش $val ج.م في هدفك 🚀'),
                    backgroundColor: AppTheme.emerald,
                  ),
                );
              }
            },
            child: const Text('إيداع'),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final targetController = TextEditingController();
    String selectedIcon = '🎯';

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
              const SizedBox(height: 24),
              CustomButton(
                text: 'إنشاء الهدف والبدء في التحويش 🚀',
                backgroundColor: AppTheme.emerald,
                onPressed: () {
                  final target = double.tryParse(targetController.text.trim()) ?? 100.0;
                  if (nameController.text.trim().isNotEmpty) {
                    setState(() {
                      _goals.add(GoalModel(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameController.text.trim(),
                        target: target,
                        current: 0.0,
                        icon: selectedIcon,
                        eta: 'قريباً',
                        aiNote: 'بداية رحلة جديدة نحو تحقيق حلمك!',
                      ));
                    });
                    Navigator.pop(ctx);
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
        title: const Text('أهداف الادخار وحصالتي 🎯'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppTheme.navy, size: 26),
            onPressed: _showAddGoalDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: _goals.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final g = _goals[index];
            final percent = (g.progress * 100).toInt();

            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.navy.withOpacity(0.06),
                              shape: BoxShape.circle,
                            ),
                            child: Text(g.icon, style: const TextStyle(fontSize: 26)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                g.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.navy,
                                ),
                              ),
                              Text(
                                'حوشت ${g.current.toInt()} من أصل ${g.target.toInt()} ج.م',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$percent%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: AppTheme.emeraldDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: g.progress,
                      minHeight: 10,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // AI Note
                  if (g.aiNote.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('💡', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              g.aiNote,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.navyDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _depositToGoal(index),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navy,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.savings, size: 16),
                      label: const Text('إيداع فلوس في الهدف 🐷'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
