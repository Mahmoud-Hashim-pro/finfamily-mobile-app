import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';
import '../../core/error_handler.dart';
import '../../core/idempotency.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'family_members_screen.dart';

class AllowanceScreen extends StatefulWidget {
  const AllowanceScreen({super.key});

  @override
  State<AllowanceScreen> createState() => _AllowanceScreenState();
}

class _AllowanceScreenState extends State<AllowanceScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedChildId;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  List<dynamic> _children = [];

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get(ApiConfig.familyOverview);
      final raw = (res.data['children'] as List<dynamic>?) ?? [];
      if (!mounted) return;
      setState(() {
        _children = raw;
        if (_children.isNotEmpty) {
          final exists = _children.any((c) => c['id']?.toString() == _selectedChildId);
          if (!exists) {
            _selectedChildId = _children.first['id']?.toString();
          }
        } else {
          _selectedChildId = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _sendAllowance() async {
    final rawText = normalizeArabicDigits(_amountController.text.trim());
    final amount = double.tryParse(rawText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى إدخال مبلغ صحيح للمصروف'),
          backgroundColor: AppTheme.coral,
        ),
      );
      return;
    }

    if (amount > 100000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('الحد الأقصى للتحويل هو 100,000 ج.م'),
          backgroundColor: AppTheme.coral,
        ),
      );
      return;
    }

    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار الطفل المستلم'),
          backgroundColor: AppTheme.coral,
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final note = _noteController.text.trim();
      final idemKey = generateIdempotencyKey('allowance');
      await ApiClient().post(
        '/wallet/child/$_selectedChildId/allowance',
        data: {
          'amount': amount,
          'label': note.isNotEmpty ? note : 'المصروف',
          'idempotency_key': idemKey,
        },
      );

      if (!mounted) return;
      setState(() => _isSending = false);
      _amountController.clear();
      _noteController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تحويل $amount ج.م بنجاح إلى المحفظة! 🎉'),
          backgroundColor: AppTheme.emerald,
        ),
      );

      _loadChildren();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorHandler.getErrorMessage(e)),
          backgroundColor: AppTheme.coral,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('إرسال المصروف (Allowance)'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadChildren,
          color: AppTheme.navy,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      Text('💸', style: TextStyle(fontSize: 36)),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'تحويل يدوي فوري إلى كارت ميزة',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'تحويل مباشر يصل لحظياً لمحفظة الطفل وكارته البنكي',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.coral.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.coral),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _loadChildren,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                else if (_children.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        const Text('👶', style: TextStyle(fontSize: 40)),
                        const SizedBox(height: 12),
                        const Text(
                          'لا يوجد أطفال في العائلة بعد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'يجب إضافة طفل أولاً لتتمكن من إرسال المصروف إلى محفظته',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: AppTheme.textMuted),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const FamilyMembersScreen(),
                              ),
                            );
                            _loadChildren();
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('إضافة بطل مالي جديد'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Child Selection
                  const Text(
                    'اختر الطفل المستلم:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: _children.map((c) {
                      final childId = c['id']?.toString();
                      final isSelected = _selectedChildId == childId;
                      final bal = (c['balance'] as num?)?.toDouble() ?? 0.0;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedChildId = childId);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.emerald.withOpacity(0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.emerald
                                    : AppTheme.cardBorder,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(c['avatar'] ?? '👦',
                                    style: const TextStyle(fontSize: 28)),
                                const SizedBox(height: 6),
                                Text(
                                  c['full_name'] ?? 'ابن',
                                  style: TextStyle(
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${bal.toStringAsFixed(0)} ج.م',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.emeraldDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Quick Amount Chips
                  const Text(
                    'المبلغ (ج.م):',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [50, 100, 150, 200].map((val) {
                      return GestureDetector(
                        onTap: () {
                          _amountController.text = val.toString();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Text(
                            '$val ج.م',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppTheme.navy,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: _amountController,
                    label: 'أو أدخل مبلغاً مخصصاً',
                    hint: 'مثلاً: 120',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: _noteController,
                    label: 'ملاحظة أو سبب التحويل (اختياري)',
                    hint: 'مثلاً: مصروف نهاية الأسبوع ⭐',
                  ),
                  const SizedBox(height: 24),

                  CustomButton(
                    text: 'تحويل المصروف الآن 🚀',
                    backgroundColor: AppTheme.navy,
                    isLoading: _isSending,
                    onPressed: _sendAllowance,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
