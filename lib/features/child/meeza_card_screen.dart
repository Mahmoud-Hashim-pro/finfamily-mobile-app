import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../core/auth_state.dart';
import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/error_handler.dart';
import '../../models/card_model.dart';
import '../../widgets/meeza_card_widget.dart';

/// Today's spending counted the way the backend enforces daily_limit (_debit_spend_since):
/// debit transactions of type card_purchase or redemption since the start of the local day.
/// Server timestamps are naive UTC, so they go through parseServerDateTime (→ local time).
@visibleForTesting
double computeTodaySpent(List<dynamic> transactions, {DateTime? now}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  final todayStart = DateTime(localNow.year, localNow.month, localNow.day);
  double total = 0.0;
  for (final t in transactions) {
    if (t is! Map) continue;
    if (t['direction'] != 'debit') continue;
    if (t['type'] != 'card_purchase' && t['type'] != 'redemption') continue;
    final dt = parseServerDateTime(t['created_date']);
    if (dt != null && !dt.isBefore(todayStart)) {
      total += ((t['amount'] as num?)?.toDouble() ?? 0.0);
    }
  }
  return total;
}

class MeezaCardScreen extends StatefulWidget {
  const MeezaCardScreen({super.key, this.refreshSignal});

  /// Bumped by ChildNavShell when this tab is reopened, so the IndexedStack tab refetches.
  final ValueNotifier<int>? refreshSignal;

  @override
  State<MeezaCardScreen> createState() => _MeezaCardScreenState();
}

class _MeezaCardScreenState extends State<MeezaCardScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  double? _dailyLimit;
  // Server-computed spend for the limit window, when the backend provides it
  double? _dailySpent;
  List<dynamic> _transactions = [];
  // /transactions/mine failed on the last load (the list / today's spend may be stale)
  bool _txLoadFailed = false;

  CardModel? _card;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_handleRefresh);
    _loadCardData();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRefresh);
    super.dispose();
  }

  void _handleRefresh() {
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

      // Load child transactions (null = request failed, keep the previously loaded list)
      List<dynamic>? txList;
      try {
        final txRes = await ApiClient().get('/transactions/mine');
        txList = (txRes.data as List?) ?? [];
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _dailyLimit = (data['daily_limit'] as num?)?.toDouble();
        _dailySpent = (data['daily_spent'] as num?)?.toDouble();
        _card = CardModel(
          id: data['id']?.toString() ?? '',
          userId: data['owner_id']?.toString() ?? auth.user?['id']?.toString() ?? '',
          cardNumber: data['card_number']?.toString() ?? '',
          cardholderName: auth.user?['full_name']?.toString() ?? auth.user?['username']?.toString() ?? 'بطل مالي',
          status: data['card_status']?.toString() ?? 'active',
          expiryDate: data['card_expiry']?.toString() ?? data['expiry_date']?.toString(),
        );
        if (txList != null) _transactions = txList;
        _txLoadFailed = txList == null;
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

  double _getTodaySpent() => _dailySpent ?? computeTodaySpent(_transactions);

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
                      // Without today's transactions (and no server figure) the usage would be a guess
                      final bool usageUnknown = _txLoadFailed && _dailySpent == null;
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
                                  usageUnknown
                                      ? '? / ${_dailyLimit!.toStringAsFixed(2)} ج.م'
                                      : '${todaySpent.toStringAsFixed(2)} / ${_dailyLimit!.toStringAsFixed(2)} ج.م',
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
                              usageUnknown
                                  ? 'تعذر تحميل عمليات اليوم، اسحب للتحديث 🔄'
                                  : ratio >= 1.0
                                      ? 'وصلت للحد الأقصى المسموح به لليوم! 🛑'
                                      : 'متبقي لك اليوم: ${(_dailyLimit! - todaySpent).clamp(0.0, _dailyLimit!).toStringAsFixed(2)} ج.م 👍',
                              style: TextStyle(
                                fontSize: 11,
                                color: (ratio >= 1.0 || usageUnknown) ? AppTheme.coral : AppTheme.textMuted,
                                fontWeight: (ratio >= 1.0 || usageUnknown) ? FontWeight.bold : FontWeight.normal,
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

                if (_txLoadFailed && _transactions.isNotEmpty && !_isLoading)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.coral.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'تعذر تحديث العمليات، قد تكون القائمة غير محدثة. اسحب للتحديث 🔄',
                      style: TextStyle(fontSize: 11, color: AppTheme.coral, fontWeight: FontWeight.bold),
                    ),
                  ),

                if (_isLoading && _transactions.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppTheme.emerald),
                    ),
                  )
                else if (_txLoadFailed && _transactions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 36, color: Colors.redAccent),
                        const SizedBox(height: 8),
                        const Text(
                          'تعذر تحميل عمليات الكارت',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppTheme.navy, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
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
                              '${isCredit ? "+" : "-"}${amount.toStringAsFixed(2)} ج.م',
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
