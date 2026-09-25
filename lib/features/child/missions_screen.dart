import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/mission_model.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  final List<MissionModel> _missions = [
    MissionModel(
      id: 'm1',
      title: 'ترتيب وتنظيف غرفة النوم',
      description: 'رتّب السرير والمكتب وتأكد من تنظيم الألعاب',
      rewardAmount: 25.0,
      rewardXp: 40,
      status: 'pending',
      kind: 'chore',
    ),
    MissionModel(
      id: 'm2',
      title: 'مذاكرة وحل واجب الرياضيات بالكامل',
      description: 'حل تمارين الدرس الثاني في الجبر',
      rewardAmount: 30.0,
      rewardXp: 50,
      status: 'submitted',
      kind: 'chore',
    ),
    MissionModel(
      id: 'm3',
      title: 'مساعدة ماما في تحضير سفرة الغداء',
      description: 'وضع الأطباق وتجهيز الملاعق',
      rewardAmount: 15.0,
      rewardXp: 30,
      status: 'approved',
      kind: 'chore',
    ),
  ];

  void _submitMission(int index) {
    setState(() {
      final current = _missions[index];
      _missions[index] = MissionModel(
        id: current.id,
        title: current.title,
        description: current.description,
        rewardAmount: current.rewardAmount,
        rewardXp: current.rewardXp,
        status: 'submitted',
        kind: current.kind,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال إشعار الإنجاز لبابا/ماما للموافقة وصرف المكافأة! 🎉'),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('المهام والفلوس (Missions) 🧹'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: _missions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final m = _missions[index];

            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: m.isApproved
                      ? AppTheme.emerald.withOpacity(0.4)
                      : AppTheme.cardBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('🧹', style: TextStyle(fontSize: 24)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.navy,
                                ),
                              ),
                              Text(
                                '+${m.rewardXp} XP إضافية',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.emeraldDark,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.gold.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+${m.rewardAmount.toStringAsFixed(0)} ج.م',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppTheme.navy,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    m.description,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  if (m.isPending)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _submitMission(index),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text(
                          'أنجزت المهمة يا بابا! 🚀',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else if (m.isSubmitted)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.hourglass_top, size: 16, color: Colors.amber),
                          SizedBox(width: 8),
                          Text(
                            'بانتظار موافقة ولي الأمر لإضافة الرصيد لكارتك ⏳',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (m.isApproved)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle, size: 16, color: AppTheme.emerald),
                          SizedBox(width: 8),
                          Text(
                            'تمت الموافقة والمكافأة نزلت في كارتك بنجاح! 🥳',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.emeraldDark,
                            ),
                          ),
                        ],
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
