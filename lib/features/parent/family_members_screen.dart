import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';
import '../../core/auth_state.dart';
import '../../core/error_handler.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  String _familyCode = '---';
  String _familyName = '';
  List<dynamic> _children = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final codeRes = await ApiClient().get(ApiConfig.familyCode);
      final childrenRes = await ApiClient().get(ApiConfig.familyChildren);

      setState(() {
        _familyCode = codeRes.data['family_code'] ?? '---';
        _familyName = codeRes.data['family_name'] ?? '';
        _children = childrenRes.data['children'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  void _showAddChildDialog() {
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    String selectedAvatar = '👦';
    bool isSubmitting = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إضافة بطل مالي جديد 🧒',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'سيتم إنشاء حساب للطفل وتوليد كارت ميزة افتراضي له فوراً',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              if (dialogError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.coral.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    dialogError!,
                    style: const TextStyle(color: AppTheme.coral, fontSize: 12),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: ['👦', '👧', '🦁', '🚀', '⭐'].map((emoji) {
                  final isSelected = selectedAvatar == emoji;
                  return GestureDetector(
                    onTap: () => setModalState(() => selectedAvatar = emoji),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.emerald.withOpacity(0.2)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.emerald
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 26)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: nameController,
                label: 'اسم الطفل بالكامل',
                hint: 'مثلاً: عمر أحمد',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: pinController,
                label: 'رمز PIN الخاص به (6 أرقام)',
                hint: '123456',
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'إنشاء حساب الطفل والكارت',
                backgroundColor: AppTheme.emerald,
                isLoading: isSubmitting,
                onPressed: () async {
                  final name = nameController.text.trim();
                  final pin = pinController.text.trim();

                  if (name.isEmpty) {
                    setModalState(() => dialogError = 'يرجى إدخال اسم الطفل');
                    return;
                  }
                  if (pin.length != 6 || int.tryParse(pin) == null) {
                    setModalState(() =>
                        dialogError = 'رمز الـ PIN يجب أن يتكون من 6 أرقام');
                    return;
                  }

                  setModalState(() {
                    isSubmitting = true;
                    dialogError = null;
                  });

                  try {
                    await ApiClient().post(
                      ApiConfig.createChild,
                      data: {
                        'full_name': name,
                        'pin': pin,
                      },
                    );

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text('تم تسجيل $name وتوليد كارت ميزة بنجاح! 💳'),
                        backgroundColor: AppTheme.emerald,
                      ),
                    );

                    _loadData();
                  } catch (e) {
                    setModalState(() {
                      isSubmitting = false;
                      dialogError = ApiErrorHandler.getErrorMessage(e);
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('أفراد العائلة والكود'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.navy,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.coral.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppTheme.coral.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.coral),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.coral, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),

                // Family Code Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2D52), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.navy.withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _familyName.isNotEmpty
                            ? 'كود عائلة $_familyName'
                            : 'كود العائلة الخاص بكم (Family Code)',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _familyCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 14),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _familyCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'تم نسخ كود العائلة إلى الحافظة! 📋'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, color: AppTheme.gold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'أعطِ هذا الكود لأولادك ليسجلوا به في تطبيق الهاتف مع الـ PIN الخاص بهم.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'أعضاء العائلة المسجلين:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showAddChildDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة طفل'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Parent Card
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.navy.withOpacity(0.1),
                        child: const Text('👨', style: TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user?['full_name'] ?? 'ولي الأمر',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'ولي الأمر (المسؤول)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Children List or Empty State
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_children.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        const Text('🧒', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        const Text(
                          'لا يوجد أطفال مسجلون في هذه العائلة بعد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'اضغط على زر "إضافة طفل" بالأعلى لإنشاء أول حساب',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _children.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final c = _children[index];
                      final last4 = c['id'] != null
                          ? (c['id'].toString().length >= 4
                              ? c['id']
                                  .toString()
                                  .substring(c['id'].toString().length - 4)
                              : '0000')
                          : '0000';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  AppTheme.emerald.withOpacity(0.12),
                              child: const Text('👦',
                                  style: TextStyle(fontSize: 26)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['full_name'] ?? 'بطل مالي',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'بطل مالي',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '5061 •••• •••• $last4',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textMuted,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
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
