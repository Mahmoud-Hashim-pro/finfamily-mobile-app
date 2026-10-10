import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_state.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../child/child_nav_shell.dart';

class ChildLoginScreen extends StatefulWidget {
  const ChildLoginScreen({super.key});

  @override
  State<ChildLoginScreen> createState() => _ChildLoginScreenState();
}

class _ChildLoginScreenState extends State<ChildLoginScreen> {
  final _familyCodeController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLookingUp = false;
  List<dynamic>? _children;
  Map<String, dynamic>? _selectedChild;
  String? _error;

  @override
  void dispose() {
    _familyCodeController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _lookupFamily() async {
    final code = _familyCodeController.text.trim();
    if (code.isEmpty || code.length < 4) {
      setState(() => _error = 'يرجى كتابة كود العائلة المكون من 6 خانات');
      return;
    }

    setState(() {
      _isLookingUp = true;
      _error = null;
    });

    try {
      final res = await ApiClient().post(
        ApiConfig.childLookup,
        data: {'family_code': code.toUpperCase()},
      );

      final list = res.data['children'] as List<dynamic>? ?? [];
      if (list.isEmpty) {
        setState(() {
          _error = 'لم يتم العثور على أطفال مسجلين في هذه العائلة بعد';
          _isLookingUp = false;
        });
      } else {
        setState(() {
          _children = list;
          _isLookingUp = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = ApiErrorHandler.getErrorMessage(e);
        _isLookingUp = false;
      });
    }
  }

  Future<void> _handleChildLogin() async {
    if (_selectedChild == null) return;
    final pin = _pinController.text.trim();
    if (pin.length != 6 || int.tryParse(pin) == null) {
      setState(() => _error = 'رمز PIN يجب أن يتكون من 6 أرقام');
      return;
    }

    final auth = Provider.of<AuthState>(context, listen: false);
    final success = await auth.loginChild(
      _familyCodeController.text.trim(),
      _selectedChild!['id'],
      pin,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ChildNavShell()),
        (route) => false,
      );
    } else if (auth.errorMessage != null) {
      setState(() => _error = auth.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('دخول الأبطال الماليين 🚀'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppTheme.emerald, AppTheme.emeraldDark],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.emerald.withOpacity(0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🌟', style: TextStyle(fontSize: 40)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'مرحباً يا بطل! 💳',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'أدخل كود العائلة اللي بابا أو ماما عطاهولك',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 28),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.coral.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.coral.withOpacity(0.3)),
                  ),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.coral,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Step 1: Family Code
              if (_children == null) ...[
                CustomTextField(
                  controller: _familyCodeController,
                  label: 'كود العائلة (6 أحرف أو أرقام)',
                  hint: 'مثلاً: AB12CD',
                  keyboardType: TextInputType.text,
                  prefixIcon: Icons.family_restroom,
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'البحث عن عائلتي',
                  backgroundColor: AppTheme.emerald,
                  isLoading: _isLookingUp,
                  onPressed: _lookupFamily,
                ),
              ] else if (_selectedChild == null) ...[
                // Step 2: Select Avatar / Profile
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'اختر حسابك:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _children = null),
                      child: const Text('تغيير الكود'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.05,
                  ),
                  itemCount: _children!.length,
                  itemBuilder: (context, index) {
                    final c = _children![index];
                    return GestureDetector(
                      onTap: () => setState(() => _selectedChild = c),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.emerald.withOpacity(0.5),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.emerald.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              c['avatar'] ?? '👦',
                              style: const TextStyle(fontSize: 38),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              c['full_name'] ?? 'بطل مالي',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Level ${c['level'] ?? 1}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.emeraldDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ] else ...[
                // Step 3: Enter PIN
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          _selectedChild!['avatar'] ?? '👦',
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedChild!['full_name'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => setState(() => _selectedChild = null),
                      child: const Text('تغيير البطل'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomTextField(
                  controller: _pinController,
                  label: 'رمز الـ PIN السري الخاص بك (6 أرقام)',
                  hint: '••••••',
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  prefixIcon: Icons.lock_clock_outlined,
                ),
                const SizedBox(height: 28),
                CustomButton(
                  text: 'دخول إلى حسابي 🚀',
                  backgroundColor: AppTheme.emerald,
                  isLoading: auth.status == AuthStatus.loading,
                  onPressed: _handleChildLogin,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
