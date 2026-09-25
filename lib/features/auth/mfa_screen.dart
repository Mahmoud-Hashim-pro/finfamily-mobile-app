import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_state.dart';
import '../../config/theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../parent/parent_nav_shell.dart';

class MfaScreen extends StatefulWidget {
  const MfaScreen({super.key});

  @override
  State<MfaScreen> createState() => _MfaScreenState();
}

class _MfaScreenState extends State<MfaScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رمز التحقق يتكون من 6 أرقام'),
          backgroundColor: AppTheme.coral,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthState>(context, listen: false);
    final success = await auth.verifyMfa(code);

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ParentNavShell()),
        (route) => false,
      );
    } else if (auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage!),
          backgroundColor: AppTheme.coral,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('التحقق بخطوتين (2FA)'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.navy.withOpacity(0.08),
                  ),
                  child: const Center(
                    child: Icon(Icons.security, size: 36, color: AppTheme.navy),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'تأكيد هوية ولي الأمر',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'أدخل الرمز المكون من 6 أرقام من تطبيق الموثق (Google/Microsoft Authenticator)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 36),

              CustomTextField(
                controller: _codeController,
                label: 'رمز التحقق (6 أرقام)',
                hint: '123456',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.lock_outline,
              ),
              const SizedBox(height: 30),

              CustomButton(
                text: 'تأكيد ودخول',
                isLoading: auth.status == AuthStatus.loading,
                onPressed: _handleVerify,
              ),
              const SizedBox(height: 16),

              Center(
                child: TextButton(
                  onPressed: () {
                    // Recovery code dialog
                    _showRecoveryDialog(context);
                  },
                  child: const Text('استخدام كود استعادة الطوارئ (Recovery Code)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecoveryDialog(BuildContext context) {
    final recoveryController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('كود الاستعادة'),
        content: TextField(
          controller: recoveryController,
          decoration: const InputDecoration(
            hintText: 'XXXXX-XXXXX',
            labelText: 'أدخل كود الطوارئ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _codeController.text = recoveryController.text.trim();
              _handleVerify();
            },
            child: const Text('تحقق'),
          ),
        ],
      ),
    );
  }
}
