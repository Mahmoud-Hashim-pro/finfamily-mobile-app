import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../widgets/custom_button.dart';

class SpendingLimitsScreen extends StatefulWidget {
  const SpendingLimitsScreen({super.key});

  @override
  State<SpendingLimitsScreen> createState() => _SpendingLimitsScreenState();
}

class _SpendingLimitsScreenState extends State<SpendingLimitsScreen> {
  double _dailyLimit = 100.0;
  double _weeklyLimit = 500.0;
  double _monthlyLimit = 1500.0;

  final Map<String, bool> _blockedCategories = {
    'ألعاب الفيديو والشحن الإلكتروني 🎮': true,
    'الوجبات السريعة والمطاعم 🍔': false,
    'المشتريات والتسوق أونلاين 🛍️': false,
    'السينما والترفيه 🎬': false,
    'التطبيقات والاشتراكات الشهرية 📱': true,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('حدود الصرف وحظر الفئات'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Intro
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: const Row(
                  children: [
                    Text('🛡️', style: TextStyle(fontSize: 32)),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'حماية مالية ذكية لأطفالك',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.navy,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'أي عملية تتجاوز الحدود المحددة تتطلب موافقتك الصريحة قبل أن تتم.',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'الحدود المالية المسموحة:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
              ),
              const SizedBox(height: 14),

              // Daily Limit Slider
              _buildLimitCard(
                title: 'الحد اليومي للصرف',
                value: _dailyLimit,
                max: 500,
                onChanged: (val) => setState(() => _dailyLimit = val),
              ),
              const SizedBox(height: 12),

              // Weekly Limit Slider
              _buildLimitCard(
                title: 'الحد الأسبوعي للصرف',
                value: _weeklyLimit,
                max: 2000,
                onChanged: (val) => setState(() => _weeklyLimit = val),
              ),
              const SizedBox(height: 12),

              // Monthly Limit Slider
              _buildLimitCard(
                title: 'الحد الشهري للصرف',
                value: _monthlyLimit,
                max: 5000,
                onChanged: (val) => setState(() => _monthlyLimit = val),
              ),
              const SizedBox(height: 28),

              const Text(
                'الفئات المحظورة تلقائياً (Blocked Categories):',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
              ),
              const SizedBox(height: 6),
              const Text(
                'سيتم رفض أي محاولة شراء تتبع هذه الفئات فوراً لحماية طفلك.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  children: _blockedCategories.keys.map((cat) {
                    final isBlocked = _blockedCategories[cat]!;
                    return SwitchListTile(
                      activeColor: AppTheme.coral,
                      title: Text(
                        cat,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isBlocked ? 'محظور من الكارت 🚫' : 'مسموح به ✅',
                        style: TextStyle(
                          fontSize: 11,
                          color: isBlocked ? AppTheme.coral : AppTheme.emeraldDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      value: isBlocked,
                      onChanged: (val) {
                        setState(() {
                          _blockedCategories[cat] = val;
                        });
                      },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 28),

              CustomButton(
                text: 'حفظ الحدود والإعدادات',
                backgroundColor: AppTheme.navy,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حفظ حدود الصرف وقواعد الأمان بنجاح! 🔒'),
                      backgroundColor: AppTheme.emerald,
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

  Widget _buildLimitCard({
    required String title,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              Text(
                '${value.toInt()} ج.م',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.navy,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 20,
            max: max,
            divisions: 20,
            activeColor: AppTheme.navy,
            inactiveColor: AppTheme.navy.withOpacity(0.1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
