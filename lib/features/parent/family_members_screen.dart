import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  final String _familyCode = 'FF2026';

  final List<Map<String, dynamic>> _members = [
    {
      'name': 'أحمد حسن',
      'role': 'ولي الأمر (المسؤول)',
      'avatar': '👨',
      'isParent': true,
    },
    {
      'name': 'لطفي',
      'role': 'بطل مالي · 10 سنوات',
      'avatar': '👦',
      'isParent': false,
      'level': 3,
      'card': '5061 •••• •••• 1234',
    },
    {
      'name': 'سارة',
      'role': 'بطل مالي · 8 سنوات',
      'avatar': '👧',
      'isParent': false,
      'level': 2,
      'card': '5061 •••• •••• 5678',
    },
  ];

  void _showAddChildDialog() {
    final nameController = TextEditingController();
    final ageController = TextEditingController();
    final pinController = TextEditingController();
    String selectedAvatar = '👦';

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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navy),
              ),
              const SizedBox(height: 16),
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
                        color: isSelected ? AppTheme.emerald.withOpacity(0.2) : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.emerald : Colors.transparent,
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
                label: 'اسم الطفل',
                hint: 'مثلاً: عمر',
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: ageController,
                label: 'العمر',
                hint: '10',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: pinController,
                label: 'رمز PIN الخاص به (4 أرقام للدخول)',
                hint: '1234',
                keyboardType: TextInputType.number,
                obscureText: true,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'إنشاء حساب الطفل والكارت',
                backgroundColor: AppTheme.emerald,
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    setState(() {
                      _members.add({
                        'name': nameController.text.trim(),
                        'role': 'بطل مالي · ${ageController.text} سنوات',
                        'avatar': selectedAvatar,
                        'isParent': false,
                        'level': 1,
                        'card': '5061 •••• •••• 9999',
                      });
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة الطفل وتوليد كارت ميزة بنجاح! 💳'),
                        backgroundColor: AppTheme.emerald,
                      ),
                    );
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('أفراد العائلة والكود'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    const Text(
                      'كود العائلة الخاص بكم (Family Code)',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
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
                            Clipboard.setData(ClipboardData(text: _familyCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم نسخ كود العائلة إلى الحافظة! 📋'),
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

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _members.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final m = _members[index];
                  final isParent = m['isParent'] == true;

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
                          backgroundColor: isParent
                              ? AppTheme.navy.withOpacity(0.1)
                              : AppTheme.emerald.withOpacity(0.12),
                          child: Text(m['avatar'], style: const TextStyle(fontSize: 26)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                m['role'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                              if (!isParent) ...[
                                const SizedBox(height: 2),
                                Text(
                                  m['card'],
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textMuted,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isParent)
                          IconButton(
                            icon: const Icon(Icons.password, size: 20, color: AppTheme.navy),
                            tooltip: 'تغيير الـ PIN',
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('تعديل PIN لـ ${m['name']}')),
                              );
                            },
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
