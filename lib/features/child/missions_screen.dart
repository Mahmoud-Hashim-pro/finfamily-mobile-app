import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import '../../models/mission_model.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<MissionModel> _missions = [];

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get('/missions/mine');
      final rawList = (res.data as List?) ?? [];

      final List<MissionModel> loaded = rawList.map((m) {
        return MissionModel(
          id: m['id'] ?? '',
          title: m['title'] ?? 'مهمة عائلية',
          description: m['description'] ?? '',
          rewardAmount: ((m['reward_egp'] ?? m['reward'] ?? m['reward_amount'] ?? 0.0) as num).toDouble(),
          rewardXp: ((m['reward_coins'] ?? m['reward_points'] ?? m['reward_xp'] ?? 50) as num).toInt(),
          status: m['status'] ?? 'pending',
          kind: m['kind'] ?? 'chore',
          proofText: m['proof_text'] ?? m['proof'],
          proofUrl: m['proof_url'],
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _missions = loaded;
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

  void _submitMission(int index) {
    final proofController = TextEditingController();
    final proofUrlController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('تأكيد إنجاز "${_missions[index].title}"'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'اكتب رسالة أو إثبات لبابا وماما بأنك أنجزت المهمة:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: proofController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل الإنجاز *',
                    hintText: 'مثلاً: رتبت سريري وغرفتي تمام يا ماما! 👍',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: proofUrlController,
                  decoration: const InputDecoration(
                    labelText: 'رابط صورة أو إثبات (اختياري)',
                    hintText: 'https://...',
                    prefixIcon: Icon(Icons.link, size: 18),
                  ),
                ),
                if (dialogError != null) ...[
                  const SizedBox(height: 8),
                  Text(dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () {
                      proofController.dispose();
                      proofUrlController.dispose();
                      Navigator.pop(ctx);
                    },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final proof = proofController.text.trim();
                      final proofUrl = proofUrlController.text.trim();
                      if (proof.isEmpty) {
                        setDialogState(() => dialogError = 'اكتب كلمة توضح أنك أنجزت المهمة');
                        return;
                      }

                      setDialogState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      try {
                        final m = _missions[index];
                        await ApiClient().post(
                          '/missions/${m.id}/submit',
                          data: {
                            'proof_text': proof,
                            if (proofUrl.isNotEmpty) 'proof_url': proofUrl,
                            'note': proof,
                          },
                        );

                        proofController.dispose();
                        proofUrlController.dispose();

                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _loadMissions();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('تم إرسال إشعار الإنجاز لولي الأمر للموافقة وصرف المكافأة! 🎉'),
                            backgroundColor: AppTheme.emerald,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() {
                          isSubmitting = false;
                          dialogError = ApiErrorHandler.getErrorMessage(e);
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('إرسال للمراجعة 🚀'),
            ),
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
        title: const Text('المهام والفلوس (Missions) 🧹'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadMissions,
          color: AppTheme.emerald,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Motivational Card
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
                        child: const Text('⭐', style: TextStyle(fontSize: 28)),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'أنجز مهامك واكسب فلوس حقيقية!',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'كل مهمة بتخلصها بيتحول ثمنها لكارت ميزة بتاعك أول ما بابا/ماما يوافقوا عليها 💳',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
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

                const Text(
                  'قائمة المهام العائلية:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 12),

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
                          onPressed: _loadMissions,
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
                else if (_missions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: const Column(
                      children: [
                        Text('🎉', style: TextStyle(fontSize: 40)),
                        SizedBox(height: 12),
                        Text(
                          'لا توجد مهام حالية مخصصة لك',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'اطلب من بابا أو ماما إضافة مهمة منزلية جديدة لتحصل على مكافأة في كارتك!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _missions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final m = _missions[index];

                      Color badgeColor;
                      String statusText;
                      Color textColor;

                      switch (m.status) {
                        case 'approved':
                          badgeColor = AppTheme.emerald.withOpacity(0.15);
                          textColor = AppTheme.emeraldDark;
                          statusText = 'تمت الموافقة وصرف المكافأة ✅';
                          break;
                        case 'submitted':
                          badgeColor = AppTheme.gold.withOpacity(0.2);
                          textColor = Colors.amber.shade900;
                          statusText = 'قيد مراجعة الوالدين ⏳';
                          break;
                        default:
                          badgeColor = AppTheme.blue.withOpacity(0.12);
                          textColor = AppTheme.blue;
                          statusText = 'جاهزة للإنجاز 🚀';
                      }

                      return Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    m.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: AppTheme.navy,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (m.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                m.description,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.emerald.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '+${m.rewardAmount.toStringAsFixed(0)} ج.م',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: AppTheme.emeraldDark,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppTheme.gold.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '+${m.rewardXp} XP ⭐',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: Colors.amber.shade900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (m.status == 'pending')
                                  ElevatedButton(
                                    onPressed: () => _submitMission(index),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.emerald,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    ),
                                    child: const Text('أنجزت المهمة ✅', style: TextStyle(fontSize: 12)),
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
