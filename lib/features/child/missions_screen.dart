import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import '../../models/mission_model.dart';

/// Parses a /missions/mine item. XP mirrors the backend award on approval:
/// chores give int(reward) XP (review_mission → apply_xp(child, int(mission.reward))), redemptions give none.
@visibleForTesting
MissionModel parseChildMission(Map m) {
  final kind = (m['kind'] ?? 'chore').toString();
  final reward = ((m['reward_egp'] ?? m['reward'] ?? m['reward_amount'] ?? 0.0) as num).toDouble();
  return MissionModel(
    id: (m['id'] ?? '').toString(),
    title: (m['title'] ?? 'مهمة عائلية').toString(),
    description: (m['description'] ?? '').toString(),
    rewardAmount: reward,
    rewardXp: m['reward_xp'] != null
        ? (m['reward_xp'] as num).toInt()
        : (kind == 'chore' ? reward.toInt() : 0),
    status: (m['status'] ?? 'pending').toString(),
    kind: kind,
    proofText: (m['proof_text'] ?? m['proof'])?.toString(),
    proofUrl: m['proof_url']?.toString(),
  );
}

/// Joins several /missions/mine pages in order, keeping the first occurrence of each mission id.
@visibleForTesting
List<Map> mergeMissionPages(List<List<dynamic>> pages) {
  final seen = <String>{};
  final merged = <Map>[];
  for (final page in pages) {
    for (final m in page) {
      if (m is! Map) continue;
      final id = (m['id'] ?? '').toString();
      if (id.isNotEmpty && !seen.add(id)) continue;
      merged.add(m);
    }
  }
  return merged;
}

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<MissionModel> _missions = [];
  // Parent's note on reviewed missions (review_note), keyed by mission id
  Map<String, String> _reviewNotes = {};

  @override
  void initState() {
    super.initState();
    _loadMissions();
  }

  Future<void> _loadMissions() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final api = ApiClient();
      // Actionable missions are fetched by status so they never drop off the newest-50 page;
      // the unfiltered page only supplies recent history (approved / rejected).
      final responses = await Future.wait([
        api.get(ApiConfig.missionsMine, queryParameters: {'status': 'pending', 'limit': 100}),
        api.get(ApiConfig.missionsMine, queryParameters: {'status': 'submitted', 'limit': 100}),
        api.get(ApiConfig.missionsMine, queryParameters: {'limit': 50}),
      ]);
      final rawList = mergeMissionPages(
        responses.map((r) => (r.data as List?) ?? <dynamic>[]).toList(),
      );

      final List<MissionModel> loaded = rawList.map(parseChildMission).toList();
      final Map<String, String> notes = {};
      for (final m in rawList) {
        final note = m['review_note']?.toString().trim() ?? '';
        if (note.isNotEmpty) notes[(m['id'] ?? '').toString()] = note;
      }

      if (!mounted) return;
      setState(() {
        _missions = loaded;
        _reviewNotes = notes;
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

  Future<void> _submitMission(int index) async {
    final submitted = await showDialog<bool>(
      context: context,
      builder: (_) => _SubmitMissionDialog(
        mission: _missions[index],
        // Refresh the list whenever the submit succeeds, even if the dialog is gone by then
        onSubmitted: () {
          if (mounted) _loadMissions();
        },
      ),
    );
    if (submitted != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال إشعار الإنجاز لولي الأمر للموافقة وصرف المكافأة! 🎉'),
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
                          statusText = m.isRedemption ? 'تمت الموافقة على طلب الصرف ✅' : 'تمت الموافقة وصرف المكافأة ✅';
                          break;
                        case 'submitted':
                          badgeColor = AppTheme.gold.withOpacity(0.2);
                          textColor = Colors.amber.shade900;
                          statusText = m.isRedemption ? 'طلب صرف قيد مراجعة الوالدين ⏳' : 'قيد مراجعة الوالدين ⏳';
                          break;
                        case 'rejected':
                          badgeColor = AppTheme.coral.withOpacity(0.12);
                          textColor = AppTheme.coral;
                          statusText = m.isRedemption ? 'تم رفض الطلب ❌' : 'رفضها ولي الأمر ❌';
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
                            if (m.isRejected && (_reviewNotes[m.id] ?? '').isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'ملاحظة ولي الأمر: ${_reviewNotes[m.id]}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.coral),
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
                                        color: (m.isRedemption ? AppTheme.coral : AppTheme.emerald).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        // Redemptions are deducted from the balance, chores pay a reward
                                        '${m.isRedemption ? '-' : '+'}${m.rewardAmount.toStringAsFixed(2)} ج.م',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: m.isRedemption ? AppTheme.coral : AppTheme.emeraldDark,
                                        ),
                                      ),
                                    ),
                                    if (m.rewardXp > 0) ...[
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
                                  ],
                                ),
                                if (m.status == 'pending' && m.isChore)
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

/// Mission submit dialog. Owning the controllers in a State means they are disposed only after the
/// dialog route has finished its exit transition, on every dismissal path (cancel, success, barrier, back).
class _SubmitMissionDialog extends StatefulWidget {
  final MissionModel mission;
  final VoidCallback onSubmitted;

  const _SubmitMissionDialog({required this.mission, required this.onSubmitted});

  @override
  State<_SubmitMissionDialog> createState() => _SubmitMissionDialogState();
}

class _SubmitMissionDialogState extends State<_SubmitMissionDialog> {
  final TextEditingController _proofController = TextEditingController();
  final TextEditingController _proofUrlController = TextEditingController();
  bool _isSubmitting = false;
  String? _dialogError;

  @override
  void dispose() {
    _proofController.dispose();
    _proofUrlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final proof = _proofController.text.trim();
    // Sent as typed: the backend adds https:// to bare links and keeps non-link text as proof text
    final proofUrl = _proofUrlController.text.trim();
    if (proof.isEmpty) {
      setState(() => _dialogError = 'اكتب كلمة توضح أنك أنجزت المهمة');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _dialogError = null;
    });

    try {
      await ApiClient().post(
        ApiConfig.missionSubmit(widget.mission.id),
        data: {
          'proof_text': proof,
          if (proofUrl.isNotEmpty) 'proof_url': proofUrl,
          'note': proof,
        },
      );

      widget.onSubmitted();
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _dialogError = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // No back/barrier dismissal while the request is in flight
      canPop: !_isSubmitting,
      child: AlertDialog(
        title: Text('تأكيد إنجاز "${widget.mission.title}"'),
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
                controller: _proofController,
                maxLines: 2,
                maxLength: 500, // backend proof_text / note limit
                decoration: const InputDecoration(
                  labelText: 'تفاصيل الإنجاز *',
                  hintText: 'مثلاً: رتبت سريري وغرفتي تمام يا ماما! 👍',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _proofUrlController,
                maxLength: 500, // backend proof_url limit
                decoration: const InputDecoration(
                  labelText: 'رابط صورة أو إثبات (اختياري)',
                  hintText: 'https://...',
                  prefixIcon: Icon(Icons.link, size: 18),
                  counterText: '',
                ),
              ),
              if (_dialogError != null) ...[
                const SizedBox(height: 8),
                Text(_dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('إرسال للمراجعة 🚀'),
          ),
        ],
      ),
    );
  }
}
