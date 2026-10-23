import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_state.dart';
import '../../config/theme.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../parent/parent_nav_shell.dart';
import 'auth_input_utils.dart';

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
    // Arabic-Indic digits from Arabic keyboards are mapped to ASCII before validating/sending
    final code = normalizeNumericCode(_codeController.text);
    if (!isSixDigitCode(code)) {
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
      // The MFA challenge expired (AuthState dropped it): no code can succeed here, go back to the login form
      if (auth.status == AuthStatus.unauthenticated) Navigator.maybePop(context);
    }
  }

  Future<void> _showRecoveryDialog() async {
    // The dialog owns its controller (disposed in its State) and cannot be dismissed while
    // a request is in flight; it pops `true` on success and the screen navigates here.
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RecoveryCodeDialog(),
    );

    if (!mounted) return;
    final auth = Provider.of<AuthState>(context, listen: false);
    // ok == null: the dialog route was removed externally; still honour a completed login
    if (ok == true || (ok == null && auth.status == AuthStatus.authenticated)) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ParentNavShell()),
        (route) => false,
      );
    } else if (auth.status == AuthStatus.unauthenticated) {
      // The MFA challenge expired while the dialog was open: explain and return to the login form
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'انتهت مهلة التحقق الثنائي، يرجى تسجيل الدخول مجدداً'),
          backgroundColor: AppTheme.coral,
        ),
      );
      Navigator.maybePop(context);
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

/// Recovery-code dialog: accepts XXXX-XXXX-XXXX-XXXX (and legacy XXXX-XXXX), normalized before sending.
class _RecoveryCodeDialog extends StatefulWidget {
  const _RecoveryCodeDialog();

  @override
  State<_RecoveryCodeDialog> createState() => _RecoveryCodeDialogState();
}

class _RecoveryCodeDialogState extends State<_RecoveryCodeDialog> {
  final _recoveryController = TextEditingController();
  bool _isSubmitting = false;
  String? _dialogError;

  @override
  void dispose() {
    _recoveryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Uppercase + strip spaces/dashes: 'abcd-efgh 2345-6789' → 'ABCDEFGH23456789' (16 chars fit /auth/mfa/verify)
    final rawCode = normalizeRecoveryCode(_recoveryController.text);
    if (!isValidRecoveryCode(rawCode)) {
      setState(() {
        _dialogError = 'صيغة كود الاستعادة غير صحيحة، يجب أن يكون مثل: ABCD-EFGH-2345-6789';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _dialogError = null;
    });

    final auth = Provider.of<AuthState>(context, listen: false);
    final success = await auth.loginParentWithRecovery(rawCode);

    if (!mounted) return;
    if (success) {
      Navigator.pop(context, true);
      return;
    }
    if (auth.status == AuthStatus.unauthenticated) {
      // Expired challenge: the screen shows the message and returns to login
      Navigator.pop(context, false);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _dialogError = auth.errorMessage ?? 'تعذر التحقق من كود الاستعادة، حاول مرة أخرى';
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('كود استعادة الطوارئ 🔐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل أحد أكواد الاستعادة الاحتياطية التي تم إنشاؤها لحسابك بالصيغة XXXX-XXXX-XXXX-XXXX',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _recoveryController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                hintText: 'ABCD-EFGH-2345-6789',
                labelText: 'كود الاستعادة (XXXX-XXXX-XXXX-XXXX)',
                filled: true,
                fillColor: AppTheme.backgroundLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_dialogError != null) ...[
              const SizedBox(height: 8),
              Text(
                _dialogError!,
                style: const TextStyle(color: AppTheme.coral, fontSize: 12),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submit,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('دخول بكود الاستعادة'),
          ),
        ],
      ),
    );
  }
}
