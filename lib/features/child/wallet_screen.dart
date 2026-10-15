import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import 'goals_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

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
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get('/wallet/me');
      final data = res.data;
      final goals = (data['savings_goals'] as List?) ?? [];

      List<dynamic> txList = [];
      try {
        final txRes = await ApiClient().get('/transactions/mine');
        txList = (txRes.data as List?) ?? [];
      } catch (_) {}

      final Map<String, double> categorySums = {};
      for (var t in txList) {
        if (t is Map) {
          final direction = t['direction']?.toString();
          if (direction == 'debit') {
            final cat = t['category']?.toString() ?? 'أخرى';
            final amt = (t['amount'] as num?)?.toDouble() ?? 0.0;
            categorySums[cat] = (categorySums[cat] ?? 0.0) + amt;
          }
        }
      }

      final List<Map<String, dynamic>> calculated = [];
      final colors = [AppTheme.gold, AppTheme.emerald, AppTheme.navy, AppTheme.blue, AppTheme.purple, AppTheme.coral];
      int colorIdx = 0;
      categorySums.forEach((cat, amt) {
        calculated.add({
          'name': cat,
          'amount': amt,
          'color': colors[colorIdx % colors.length],
        });
        colorIdx++;
      });
      calculated.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

      final bool isEstimated = calculated.isEmpty;
      final List<Map<String, dynamic>> finalCategories = calculated.isNotEmpty
          ? calculated
          : [
              {'name': 'أكل وكانتين 🍔', 'amount': 0.0, 'color': AppTheme.gold},
              {'name': 'سوبرماركت 🛒', 'amount': 0.0, 'color': AppTheme.emerald},
              {'name': 'ألعاب وترفيه 🎮', 'amount': 0.0, 'color': AppTheme.navy},
            ];

      if (!mounted) return;
      setState(() {
        _walletBalance = (data['balance'] as num?)?.toDouble() ?? 0.0;
        _savingsBalance = (data['savings_balance'] as num?)?.toDouble() ?? 0.0;
        if (goals.isNotEmpty) {
          _firstGoalName = goals.first['name'];
        }
        _categories = finalCategories;
        _isCategoriesEstimated = isEstimated;
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
                              '${_walletBalance.toStringAsFixed(1)} ج.م',
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
                              '${_savingsBalance.toStringAsFixed(1)} ج.م',
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
                                  '${cat['amount']} ج.م (${(ratio * 100).toInt()}%)',
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
