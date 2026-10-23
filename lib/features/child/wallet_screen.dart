import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../core/api_client.dart';
import '../../core/date_utils.dart';
import '../../core/error_handler.dart';
import 'goals_screen.dart';

/// Card purchase categories (same labels as the parent's spending limits screen).
const Map<String, String> _purchaseCategoryLabels = {
  'Gaming': 'ألعاب الفيديو والشحن الإلكتروني 🎮',
  'Food': 'الوجبات السريعة والمطاعم 🍔',
  'Shopping': 'المشتريات والتسوق أونلاين 🛍️',
  'Entertainment': 'السينما والترفيه 🎬',
  'Electronics': 'الأجهزة الإلكترونية والتقنية 📱',
  'Toys': 'الألعاب والدمى 🧸',
};

/// Non-card spending, bucketed by transaction type.
const Map<String, String> _debitTypeLabels = {
  'redemption': 'مكافآت مصروفة 🏆',
  'adjustment': 'تعديلات ⚖️',
};

/// This month's spending per category (label → amount, rounded to piastres).
/// - Completed card purchases (/card/purchases/mine) are grouped by their real category.
/// - Other debits from /transactions/mine are grouped by type, excluding savings_transfer (the child's own
///   saving, not spending) and card_purchase (already counted from the purchases list).
/// Server timestamps are naive UTC and are converted to local time before the month check.
@visibleForTesting
Map<String, double> computeMonthlySpending(
  List<dynamic> transactions,
  List<dynamic> purchases, {
  DateTime? now,
}) {
  final localNow = (now ?? DateTime.now()).toLocal();
  bool inThisMonth(Object? raw) {
    final dt = parseServerDateTime(raw);
    return dt != null && dt.year == localNow.year && dt.month == localNow.month;
  }

  final Map<String, double> sums = {};
  void add(String label, Object? amount) {
    final amt = (amount as num?)?.toDouble() ?? 0.0;
    if (amt <= 0) return;
    sums[label] = double.parse(((sums[label] ?? 0.0) + amt).toStringAsFixed(2));
  }

  for (final p in purchases) {
    if (p is! Map) continue;
    if (p['status']?.toString() != 'completed') continue;
    if (!inThisMonth(p['created_date'])) continue;
    add(_purchaseCategoryLabels[p['category']?.toString()] ?? 'أخرى', p['amount']);
  }

  for (final t in transactions) {
    if (t is! Map) continue;
    if (t['direction']?.toString() != 'debit') continue;
    final type = t['type']?.toString() ?? '';
    if (type == 'savings_transfer' || type == 'card_purchase') continue;
    if (!inThisMonth(t['created_date'])) continue;
    add(_debitTypeLabels[type] ?? 'أخرى', t['amount']);
  }
  return sums;
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key, this.refreshSignal});

  /// Bumped by ChildNavShell when this tab is reopened, so the IndexedStack tab refetches.
  final ValueNotifier<int>? refreshSignal;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  String? _errorMessage;
  double _walletBalance = 0.0;
  double _savingsBalance = 0.0;
  String? _firstGoalName;

  List<Map<String, dynamic>> _categories = [];
  bool _isCategoriesEstimated = false;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_handleRefresh);
    _loadWallet();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRefresh);
    super.dispose();
  }

  void _handleRefresh() {
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    if (!mounted) return;
    setState(() {
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get('/wallet/me');
      final data = res.data;
      final goals = (data['savings_goals'] as List?) ?? [];

      // Spending sources (null = request failed: keep the previously shown breakdown)
      List<dynamic>? txList;
      List<dynamic>? purchaseList;
      try {
        final results = await Future.wait([
          ApiClient().get(ApiConfig.transactionsMine, queryParameters: {'limit': 100}),
          ApiClient().get(ApiConfig.cardPurchasesMine),
        ]);
        txList = (results[0].data as List?) ?? [];
        purchaseList = (results[1].data as List?) ?? [];
      } catch (_) {}

      List<Map<String, dynamic>>? calculated;
      if (txList != null && purchaseList != null) {
        final categorySums = computeMonthlySpending(txList, purchaseList);

        final List<Map<String, dynamic>> rows = [];
        final colors = [AppTheme.gold, AppTheme.emerald, AppTheme.navy, AppTheme.blue, AppTheme.purple, AppTheme.coral];
        int colorIdx = 0;
        categorySums.forEach((cat, amt) {
          rows.add({
            'name': cat,
            'amount': amt,
            'color': colors[colorIdx % colors.length],
          });
          colorIdx++;
        });
        rows.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
        calculated = rows;
      }

      if (!mounted) return;
      setState(() {
        _walletBalance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        _savingsBalance = (data['savings_balance'] as num?)?.toDouble() ?? 0.0;
        // Clear the name when the last goal was deleted
        _firstGoalName = goals.isNotEmpty ? goals.first['name']?.toString() : null;
        // On a failed spending fetch keep the previous breakdown (placeholders only on the very first load)
        if (calculated != null || _categories.isEmpty) {
          final fresh = calculated ?? <Map<String, dynamic>>[];
          _isCategoriesEstimated = fresh.isEmpty;
          _categories = fresh.isNotEmpty
              ? fresh
              : [
                  {'name': 'أكل وكانتين 🍔', 'amount': 0.0, 'color': AppTheme.gold},
                  {'name': 'سوبرماركت 🛒', 'amount': 0.0, 'color': AppTheme.emerald},
                  {'name': 'ألعاب وترفيه 🎮', 'amount': 0.0, 'color': AppTheme.navy},
                ];
        }
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('محفظتي وحصالتي 👛'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadWallet,
          color: AppTheme.emerald,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.coral, size: 36),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.navy, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _loadWallet,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.emerald,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Balances Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0F2D52), Color(0xFF1E3A8A)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'كارت ميزة المتاح',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_walletBalance.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00B894), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'في الحصالة 🐷',
                              style: TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${_savingsBalance.toStringAsFixed(2)} ج.م',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Save Money Action Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.emerald.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('🎯', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'حوّش في أهدافك المستقبلية',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.navy,
                              ),
                            ),
                            Text(
                              _firstGoalName != null ? 'هدف: $_firstGoalName 🚲' : 'ابدأ تحديد أهداف الادخار 🎯',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const GoalsScreen()),
                          ).then((_) => _loadWallet());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('تحويش', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // Spending by Category
                Row(
                  children: [
                    Text(
                      _isCategoriesEstimated
                          ? 'أين تذهب أموالك؟ (أمثلة استرشادية) 📊'
                          : 'أين تذهب أموالك هذا الشهر؟ 📊',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.navy,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Builder(builder: (context) {
                    final double total = _categories.fold<double>(
                        0.0, (sum, c) => sum + (c['amount'] as double));

                    return Column(
                      children: _categories.map((cat) {
                        final double ratio = total > 0
                            ? ((cat['amount'] as double) / total)
                            : 0.0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  cat['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${(cat['amount'] as double).toStringAsFixed(2)} ج.م (${(ratio * 100).toInt()}%)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: AppTheme.navy,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 6,
                                backgroundColor: const Color(0xFFF1F5F9),
                                valueColor: AlwaysStoppedAnimation<Color>(cat['color']),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                }),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
