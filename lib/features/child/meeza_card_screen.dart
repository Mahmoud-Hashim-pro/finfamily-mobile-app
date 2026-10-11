import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../core/auth_state.dart';
import '../../core/api_client.dart';
import '../../models/card_model.dart';
import '../../widgets/meeza_card_widget.dart';

class MeezaCardScreen extends StatefulWidget {
  const MeezaCardScreen({super.key});

  @override
  State<MeezaCardScreen> createState() => _MeezaCardScreenState();
}

class _MeezaCardScreenState extends State<MeezaCardScreen> {
  bool _isLoading = true;
  double? _dailyLimit;
  double _balance = 0.0;
  List<dynamic> _transactions = [];

  CardModel _card = CardModel(
    id: '',
    userId: '',
    cardNumber: '5061 •••• •••• 1234',
    cardholderName: 'FinFamily Hero',
    status: 'active',
    expiryDate: '12/28',
  );

  @override
  void initState() {
    super.initState();
    _loadCardData();
  }

  Future<void> _loadCardData() async {
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
          id: data['id'] ?? '',
          userId: data['owner_id'] ?? auth.user?['id'] ?? '',
          cardNumber: data['card_number'] ?? '5061 •••• •••• 1234',
          cardholderName: auth.user?['full_name'] ?? 'FinFamily Hero',
          status: data['card_status'] ?? 'active',
          expiryDate: '12/28',
        );
        _transactions = txList;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
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
                // 3D Flip Card
                MeezaCardWidget(
                  card: _card,
                  showControls: false,
                ),
                const SizedBox(height: 24),

                // Spending Limit Indicator (if set by parent)
                if (_dailyLimit != null && _dailyLimit! > 0)
                  Container(
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
                              'حد الصرف اليومي المحدد',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.navy,
                              ),
                            ),
                            Text(
                              '${_dailyLimit!.toStringAsFixed(0)} ج.م',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.emeraldDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: const LinearProgressIndicator(
                            value: 0.35,
                            minHeight: 8,
                            backgroundColor: Color(0xFFE2E8F0),
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'مضبوط بمعرفة ولي الأمر لحمايتك وتنظيم مشترياتك 👍',
                          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
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

                if (_isLoading)
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
                      final t = _transactions[index];
                      final isCredit = t['direction'] == 'credit';
                      final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
                      final desc = t['description'] ?? 'عملية كارت';

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
                                    isCredit ? '📥' : '🛒',
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
                                      isCredit ? 'إيداع في المحفظة' : 'مشتريات كارت ميزة',
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
