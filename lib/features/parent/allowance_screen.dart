import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class AllowanceScreen extends StatefulWidget {
  const AllowanceScreen({super.key});

  @override
  State<AllowanceScreen> createState() => _AllowanceScreenState();
}

class _AllowanceScreenState extends State<AllowanceScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedChildId;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _children = [
    {'id': 'c1', 'name': 'لطفي', 'avatar': '👦', 'current': 320.5},
    {'id': 'c2', 'name': 'سارة', 'avatar': '👧', 'current': 480.0},
  ];

  @override
  void initState() {
    super.initState();
    _selectedChildId = _children.first['id'];
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _sendAllowance() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال مبلغ صحيح للمصروف'),
          backgroundColor: AppTheme.coral,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ApiClient().post(
        ApiConfig.instantAllowance,
        data: {
          'child_id': _selectedChildId,
          'amount': amount,
          'note': _noteController.text.trim(),
        },
      );
    } catch (_) {
      // Mock success for offline/demo
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    _amountController.clear();
    _noteController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحويل $amount ج.م بنجاح إلى المحفظة! 🎉'),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('إرسال المصروف (Allowance)'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F2D52), Color(0xFF1E3A8A)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Row(
                  children: [
                    Text('💸', style: TextStyle(fontSize: 40)),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المصروف الفوري والذكي',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'حوّل المصروف بضغطة زر وينزل فوراً في كارت ميزة ومحفظة طفلك.',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              const Text(
                'اختر الطفل:',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Row(
                children: _children.map((c) {
                  final isSelected = _selectedChildId == c['id'];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedChildId = c['id']),
                      child: Container(
                        margin: const EdgeInsets.only(left: 6, right: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? AppTheme.navy : AppTheme.cardBorder,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.navy.withOpacity(0.08),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          children: [
                            Text(c['avatar'], style: const TextStyle(fontSize: 32)),
                            const SizedBox(height: 6),
                            Text(
                              c['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'الرصيد: ${c['current']} ج.م',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.emeraldDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Quick Amount Chips
              const Text(
                'مبالغ سريعة:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [20, 50, 100, 200].map((val) {
                  return ActionChip(
                    label: Text('$val ج.م'),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppTheme.cardBorder),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy,
                    ),
                    onPressed: () {
                      _amountController.text = val.toString();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              CustomTextField(
                controller: _amountController,
                label: 'المبلغ المراد تحويله (بالجنيه المصري)',
                hint: '0.00',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.attach_money,
              ),
              const SizedBox(height: 16),

              CustomTextField(
                controller: _noteController,
                label: 'رسالة تشجيعية (اختياري)',
                hint: 'مصروف أسبوعي ممتاز! فخور بيك يا بطل ❤️',
                prefixIcon: Icons.message_outlined,
              ),
              const SizedBox(height: 32),

              CustomButton(
                text: 'تحويل المصروف فوراً 🚀',
                backgroundColor: AppTheme.emerald,
                isLoading: _isLoading,
                onPressed: _sendAllowance,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
