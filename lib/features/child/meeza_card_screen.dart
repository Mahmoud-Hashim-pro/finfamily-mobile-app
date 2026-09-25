import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/card_model.dart';
import '../../widgets/meeza_card_widget.dart';

class MeezaCardScreen extends StatefulWidget {
  const MeezaCardScreen({super.key});

  @override
  State<MeezaCardScreen> createState() => _MeezaCardScreenState();
}

class _MeezaCardScreenState extends State<MeezaCardScreen> {
  CardModel _card = CardModel(
    id: 'c_lotfy',
    userId: 'u_lotfy',
    cardNumber: '5061 •••• •••• 1234',
    cardholderName: 'Lotfy Hassan',
    status: 'active',
    expiryDate: '12/28',
  );

  final List<Map<String, dynamic>> _cardTransactions = [
    {
      'merchant': 'Metro Market',
      'amount': -28.5,
      'category': 'بقالة وسوبرماركت',
      'icon': '🛒',
      'date': 'اليوم 09:12 ص',
    },
    {
      'merchant': 'School Canteen',
      'amount': -12.0,
      'category': 'كانتين المدرسة',
      'icon': '🥪',
      'date': 'أمس 12:30 م',
    },
    {
      'merchant': 'كتاب وقلم Bookstore',
      'amount': -35.0,
      'category': 'أدوات دراسية',
      'icon': '📚',
      'date': '24 يوليو 11:20 ص',
    },
  ];

  void _toggleFreeze() {
    setState(() {
      _card = CardModel(
        id: _card.id,
        userId: _card.userId,
        cardNumber: _card.cardNumber,
        cardholderName: _card.cardholderName,
        status: _card.isFrozen ? 'active' : 'frozen',
        expiryDate: _card.expiryDate,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _card.isFrozen
              ? 'تم تجميد الكارت مؤقتاً لحمايته 🔒'
              : 'تم تفعيل الكارت وأصبح جاهزاً للشراء 🔓',
        ),
        backgroundColor: _card.isFrozen ? AppTheme.coral : AppTheme.emerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('كارت ميزة الخاص بي 💳'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3D Flip Card
              MeezaCardWidget(
                card: _card,
                showControls: true,
                onFreezeToggle: _toggleFreeze,
              ),
              const SizedBox(height: 24),

              // Spending Limit Indicator
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
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'مصروفك اليومي المسموح به',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navy,
                          ),
                        ),
                        Text(
                          'صرفت 40.5 من 100 ج.م',
                          style: TextStyle(
                            fontSize: 12,
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
                        value: 0.405,
                        minHeight: 8,
                        backgroundColor: Color(0xFFE2E8F0),
                        valueColor:
                            AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'فاضلك 59.50 ج.م تقدر تصرفهم النهاردة 👍',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Recent Card Activity
              const Text(
                'مشتريات الكارت الأخيرة:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 12),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cardTransactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final t = _cardTransactions[index];
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
                                color: AppTheme.navy.withOpacity(0.06),
                                shape: BoxShape.circle,
                              ),
                              child: Text(t['icon'],
                                  style: const TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['merchant'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${t['category']} · ${t['date']}',
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
                          '${(t['amount'] as double).toStringAsFixed(1)} ج.م',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppTheme.coral,
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
    );
  }
}
