import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_state.dart';
import '../../config/theme.dart';
import '../auth/role_select_screen.dart';

class ChildProfileScreen extends StatelessWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);

    final List<Map<String, dynamic>> badges = [
      {'name': 'المدخر الذكي', 'icon': '🐷', 'earned': true, 'desc': 'وفّر أول 100 جنيه'},
      {'name': 'بطل الميزانية', 'icon': '🛡️', 'earned': true, 'desc': 'حافظ على حدود الصرف'},
      {'name': 'المستثمر الصغير', 'icon': '📈', 'earned': true, 'desc': 'أنهى درس الاستثمار'},
      {'name': 'قاهر الأهداف', 'icon': '🎯', 'earned': false, 'desc': 'أكمل هدفين ادخار'},
      {'name': 'مستكشف المالية', 'icon': '🧭', 'earned': false, 'desc': 'لعب 5 ألعاب مالية'},
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('الملف الشخصي للبطل 🌟'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // Avatar & Name Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.emerald.withOpacity(0.15),
                        border: Border.all(color: AppTheme.emerald, width: 3),
                      ),
                      child: const Center(
                        child: Text('👦', style: TextStyle(fontSize: 42)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      auth.user?['full_name'] ?? 'لطفي حسن',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'المستوى 3 · بطل مالي ناشئ',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.emeraldDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat('الدرجة المالية', '78/100', Colors.amber.shade800),
                        Container(width: 1, height: 30, color: Colors.grey.shade200),
                        _buildStat('الأيام المتتالية', '5 أيام 🔥', AppTheme.navy),
                        Container(width: 1, height: 30, color: Colors.grey.shade200),
                        _buildStat('المهام المنجزة', '12 مهمة ✅', AppTheme.emeraldDark),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Badges Section
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'أوسمة الإنجازات (Badges) 🏅',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                itemCount: badges.length,
                itemBuilder: (context, index) {
                  final b = badges[index];
                  final isEarned = b['earned'] == true;

                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isEarned ? Colors.white : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isEarned ? AppTheme.gold.withOpacity(0.5) : AppTheme.cardBorder,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isEarned ? b['icon'] : '🔒',
                          style: TextStyle(
                            fontSize: 28,
                            color: isEarned ? null : Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          b['name'],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isEarned ? AppTheme.navy : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          b['desc'],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await auth.logout();
                    if (!context.mounted) return;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                      (route) => false,
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.coral),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.logout, color: AppTheme.coral),
                  label: const Text(
                    'تسجيل الخروج من الحساب',
                    style: TextStyle(
                      color: AppTheme.coral,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String title, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}
