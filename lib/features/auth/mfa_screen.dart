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
    if (code.length != 6 || int.tryParse(code) == null) {
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

  void _showRecoveryDialog() {
    final recoveryController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('كود استعادة الطوارئ 🔐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أدخل أحد أكواد الاستعادة الاحتياطية التي تم إنشاؤها لحسابك بالصيغة XXXX-XXXX',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: recoveryController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'ABCD-1234',
                  labelText: 'كود الاستعادة (XXXX-XXXX)',
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(
                  dialogError!,
                  style: const TextStyle(color: AppTheme.coral, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () {
                      recoveryController.dispose();
                      Navigator.pop(ctx);
                    },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final rawCode = recoveryController.text.trim().toUpperCase();
                      final recoveryRegex = RegExp(r'^[A-Z0-9]{4}-[A-Z0-9]{4}$');

                      if (!recoveryRegex.hasMatch(rawCode)) {
                        setDialogState(() {
                          dialogError = 'صيغة كود الاستعادة غير صحيحة، يجب أن يكون مثل: ABCD-1234';
                        });
                        return;
                      }

                      setDialogState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      final auth = Provider.of<AuthState>(context, listen: false);
                      final success = await auth.loginParentWithRecovery(rawCode);

                      recoveryController.dispose();

                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);

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
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('دخول بكود الاستعادة'),
            ),
          ],
        ),
      ),
    );
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
                child: TextButton.icon(
                  onPressed: _showRecoveryDialog,
                  icon: const Icon(Icons.key, size: 18),
                  label: const Text('استخدام كود استعادة الطوارئ (Recovery Code)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
