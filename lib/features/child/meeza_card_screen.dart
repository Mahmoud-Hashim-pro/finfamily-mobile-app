import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../core/auth_state.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import '../../models/card_model.dart';
import '../../widgets/meeza_card_widget.dart';

class MeezaCardScreen extends StatefulWidget {
  const MeezaCardScreen({super.key});

  @override
  State<MeezaCardScreen> createState() => _MeezaCardScreenState();
}

class _MeezaCardScreenState extends State<MeezaCardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  double? _dailyLimit;
  double _balance = 0.0;
  List<dynamic> _transactions = [];

  CardModel? _card;

  @override
  void initState() {
    super.initState();
    _loadCardData();
  }

  Future<void> _loadCardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = Provider.of<AuthState>(context, listen: false);
      final walletRes = await ApiClient().get('/wallet/me');
      final data = walletRes.data;

      // Load child transactions
      List<dynamic> txList = [];
      try {
        final txRes = await ApiClient().get('/transactions/mine');
        txList = (txRes.data as List?) ?? [];
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        _dailyLimit = (data['daily_limit'] as num?)?.toDouble();
        _card = CardModel(
          id: data['id']?.toString() ?? '',
          userId: data['owner_id']?.toString() ?? auth.user?['id']?.toString() ?? '',
          cardNumber: data['card_number']?.toString() ?? '',
          cardholderName: auth.user?['full_name']?.toString() ?? auth.user?['username']?.toString() ?? 'بطل مالي',
          status: data['card_status']?.toString() ?? 'active',
          expiryDate: data['card_expiry']?.toString() ?? data['expiry_date']?.toString(),
        );
        _transactions = txList;
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

  double _getTodaySpent() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    double total = 0.0;
    for (var t in _transactions) {
      if (t['direction'] == 'debit' && (t['type'] == 'card_purchase' || t['type'] == 'debit')) {
        DateTime? dt;
        if (t['created_date'] != null) {
          dt = DateTime.tryParse(t['created_date'].toString());
        }
        if (dt != null && dt.isAfter(todayStart)) {
          total += ((t['amount'] as num?)?.toDouble() ?? 0.0);
        }
      }
    }
    return total;
  }

  String _getTransactionTypeLabel(Map<String, dynamic> t, bool isCredit) {
    final type = (t['type'] ?? '').toString();
    switch (type) {
      case 'card_purchase':
        return 'مشتريات كارت ميزة 💳';
      case 'savings_transfer':
        return 'تحويل لحصالة الأهداف 🎯';
      case 'allowance':
        return 'مصروف من ولي الأمر 🎁';
      case 'game_reward':
        return 'مكافأة ألعاب مالية 🎮';
      case 'mission_reward':
        return 'مكافأة مهمة منزلية 🧹';
      case 'redemption':
        return 'استبدال مكافأة 🏆';
      case 'adjustment':
        return 'تسوية رصيد ⚖️';
      default:
        return isCredit ? 'إيداع في المحفظة 📥' : 'خصم من المحفظة 📤';
    }
  }

  String _getTransactionIcon(Map<String, dynamic> t, bool isCredit) {
    final type = (t['type'] ?? '').toString();
    switch (type) {
      case 'card_purchase':
        return '🛒';
      case 'savings_transfer':
        return '🎯';
      case 'allowance':
        return '🎁';
      case 'game_reward':
        return '🎮';
      case 'mission_reward':
        return '🧹';
      case 'redemption':
        return '🏆';
      case 'adjustment':
        return '⚖️';
      default:
        return isCredit ? '📥' : '📤';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('كارت ميزة الخاص بي 💳'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCardData,
          color: AppTheme.emerald,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: Colors.redAccent),
                        const SizedBox(height: 10),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.navy, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _loadCardData,
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
                else if (_card != null)
                  Column(
                    children: [
                      MeezaCardWidget(
                        card: _card!,
                        showControls: false,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.navy.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.navy.withOpacity(0.12)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.school, size: 15, color: AppTheme.navy),
                            SizedBox(width: 6),
                            Text(
                              'بطاقة ميزة تعليمية آمنة (محاكاة مالية تفاعلية)',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navy),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else if (_isLoading)
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: const Center(child: CircularProgressIndicator(color: AppTheme.emerald)),
                  ),

                const SizedBox(height: 24),

                // Spending Limit Indicator (if set by parent)
                if (_dailyLimit != null && _dailyLimit! > 0)
                  Builder(
                    builder: (context) {
                      final todaySpent = _getTodaySpent();
                      final double ratio = (todaySpent / _dailyLimit!).clamp(0.0, 1.0);
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
                                const Text(
                                  'استهلاك حد الصرف اليومي',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                Text(
                                  '${todaySpent.toStringAsFixed(1)} / ${_dailyLimit!.toStringAsFixed(0)} ج.م',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: ratio > 0.85 ? AppTheme.coral : AppTheme.emeraldDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 8,
                                backgroundColor: const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ratio > 0.85 ? AppTheme.coral : AppTheme.emerald,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              ratio >= 1.0
                                  ? 'وصلت للحد الأقصى المسموح به لليوم! 🛑'
                                  : 'متبقي لك اليوم: ${(_dailyLimit! - todaySpent).clamp(0.0, _dailyLimit!).toStringAsFixed(1)} ج.م 👍',
                              style: TextStyle(
                                fontSize: 11,
                                color: ratio >= 1.0 ? AppTheme.coral : AppTheme.textMuted,
                                fontWeight: ratio >= 1.0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // Recent Card Activity
                const Text(
                  'مشتريات وعمليات الكارت الأخيرة:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 12),

                if (_isLoading && _transactions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppTheme.emerald),
                    ),
                  )
                else if (_transactions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: const Column(
                      children: [
                        Text('💳', style: TextStyle(fontSize: 34)),
                        SizedBox(height: 8),
                        Text(
                          'لا توجد عمليات مسجلة بعد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.navy,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'ستظهر مشتريات كارت ميزة والتحويلات هنا تلقائياً.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _transactions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final t = _transactions[index] as Map<String, dynamic>;
                      final isCredit = t['direction'] == 'credit';
                      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                      final desc = t['description'] ?? 'عملية كارت';
                      final typeLabel = _getTransactionTypeLabel(t, isCredit);
                      final iconStr = _getTransactionIcon(t, isCredit);

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isCredit
                                        ? AppTheme.emerald.withOpacity(0.1)
                                        : AppTheme.navy.withOpacity(0.06),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    iconStr,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      desc,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      typeLabel,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              '${isCredit ? "+" : "-"}${amount.toStringAsFixed(1)} ج.م',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: isCredit ? AppTheme.emerald : AppTheme.coral,
                              ),
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
