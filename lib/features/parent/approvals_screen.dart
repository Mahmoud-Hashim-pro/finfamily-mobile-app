import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/mission_model.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final List<MissionModel> _pendingApprovals = [
    MissionModel(
      id: 'm1',
      title: 'تنظيف وترتيب غرفة النوم بالكامل',
      description: 'تم الترتيب وتجهيز السرير',
      rewardAmount: 25.0,
      rewardXp: 40,
      status: 'submitted',
      kind: 'chore',
      childName: 'لطفي',
    ),
    MissionModel(
      id: 'm2',
      title: 'مذاكرة وحل واجب الرياضيات',
      description: 'أنهيت الفصل الثاني',
      rewardAmount: 30.0,
      rewardXp: 50,
      status: 'submitted',
      kind: 'chore',
      childName: 'سارة',
    ),
    MissionModel(
      id: 'm3',
      title: 'ساعة لعب بلايستيشن إضافية',
      description: 'استبدال 150 كوينز',
      rewardAmount: 15.0,
      rewardXp: 0,
      status: 'submitted',
      kind: 'redemption',
      childName: 'لطفي',
    ),
  ];

  void _handleAction(int index, bool isApproved) {
    final item = _pendingApprovals[index];
    setState(() {
      _pendingApprovals.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isApproved
              ? 'تمت الموافقة على "${item.title}" وتمت إضافة ${item.rewardAmount} ج.م للطفل! 🎉'
              : 'تم رفض طلب "${item.title}"',
        ),
        backgroundColor: isApproved ? AppTheme.emerald : AppTheme.coral,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('الموافقات المعلقة (Approvals)'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الطلبات بانتظار موافقتك:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.coral.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_pendingApprovals.length} طلبات',
                      style: const TextStyle(
                        color: AppTheme.coral,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Expanded(
                child: _pendingApprovals.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppTheme.emerald.withOpacity(0.1),
                              ),
                              child: const Center(
                                child: Icon(Icons.done_all,
                                    size: 40, color: AppTheme.emerald),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'رائع! لا توجد طلبات معلقة',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'كل طلبات ومهام أطفالك تمت مراجعتها بالكامل.',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: _pendingApprovals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = _pendingApprovals[index];
                          final isChore = item.kind == 'chore';

                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.cardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          isChore ? '🧹' : '🎁',
                                          style: const TextStyle(fontSize: 22),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          item.childName ?? 'الطفل',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppTheme.navy,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.gold.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '+${item.rewardAmount.toStringAsFixed(0)} ج.م',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: AppTheme.navy,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                if (item.description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.description,
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () =>
                                            _handleAction(index, false),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppTheme.coral,
                                          side: const BorderSide(
                                              color: AppTheme.coral),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(Icons.close, size: 16),
                                        label: const Text('رفض'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () =>
                                            _handleAction(index, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppTheme.emerald,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(Icons.check, size: 16),
                                        label: const Text('موافقة وصرف'),
                                      ),
                                    ),
                                  ],
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
