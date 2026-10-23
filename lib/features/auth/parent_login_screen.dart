import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_state.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/google_icon_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'parent_register_screen.dart';
import 'mfa_screen.dart';
import 'auth_input_utils.dart';
import '../parent/parent_nav_shell.dart';

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({super.key});

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showForgotPasswordDialog() async {
    // Dialogs own their controllers (disposed in State.dispose) and block dismissal while a request is in flight
    final result = await showDialog<_ForgotPasswordResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ForgotPasswordDialog(initialEmail: _emailController.text.trim()),
    );

    if (!mounted || result == null) return;
    if (result.openReset) {
      await _showResetPasswordDialog();
    } else if (result.sentTo != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إرسال تعليمات استعادة كلمة المرور إلى ${result.sentTo} ✉️'),
          backgroundColor: AppTheme.emerald,
        ),
      );
    }
  }

  Future<void> _showResetPasswordDialog() async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ResetPasswordDialog(),
    );

    if (!mounted || success != true) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إعادة تعيين كلمة المرور بنجاح! يمكنك الآن تسجيل الدخول. 🎉'),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthState>(context, listen: false);
    final success = await auth.loginParent(
      _emailController.text,
      _passwordController.text,
    );

    if (!mounted) return;

    if (auth.status == AuthStatus.requiresMfa) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MfaScreen()),
      );
    } else if (success) {
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

  Future<void> _handleGoogleLogin() async {
    final auth = Provider.of<AuthState>(context, listen: false);
    setState(() => _isGoogleLoading = true);

    try {
      final success = await auth.loginWithGoogle(createIfMissing: false);
      if (!mounted) return;

      if (auth.status == AuthStatus.requiresMfa) {
        // Parent has MFA enabled: complete the Google challenge with TOTP / recovery code
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MfaScreen()),
        );
      } else if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ParentNavShell()),
          (route) => false,
        );
      } else if (auth.isGoogleAccountUnregistered) {
        // Account not registered yet; show clear feedback and route to registration
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    auth.errorMessage ?? 'هذا الحساب غير مسجل بعد في FinFamily. جاري توجيهك لصفحة التسجيل...',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.navy,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ParentRegisterScreen(
              initialEmail: auth.pendingGoogleEmail,
              initialName: auth.pendingGoogleName,
            ),
          ),
        );
      } else if (auth.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage!),
            backgroundColor: AppTheme.coral,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إتمام الدخول عبر Google: ${e.toString()}'),
          backgroundColor: AppTheme.coral,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('دخول ولي الأمر'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.navy.withOpacity(0.08),
                    ),
                    child: const Center(
                      child: Text('👔', style: TextStyle(fontSize: 34)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'مرحباً بك مجدداً!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.navy,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'أدخل بريدك الإلكتروني وكلمة المرور لمتابعة عائلتك',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),

                CustomTextField(
                  controller: _emailController,
                  label: 'البريد الإلكتروني',
                  hint: 'name@example.com',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يرجى إدخال البريد الإلكتروني';
                    }
                    if (!value.contains('@')) {
                      return 'صيغة البريد الإلكتروني غير صحيحة';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                CustomTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  hint: '••••••••',
                  obscureText: _obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                      color: AppTheme.textMuted,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'يرجى إدخال كلمة المرور';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text('نسيت كلمة المرور؟'),
                  ),
                ),
                const SizedBox(height: 24),

                CustomButton(
                  text: 'تسجيل الدخول',
                  isLoading: auth.status == AuthStatus.loading && !_isGoogleLoading,
                  onPressed: _handleLogin,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'أو',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                  ],
                ),
                const SizedBox(height: 16),

                // Prominent Google / Gmail Sign-in Button
                Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDADCE0), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: auth.status == AuthStatus.loading ? null : _handleGoogleLogin,
                      child: Center(
                        child: auth.status == AuthStatus.loading && _isGoogleLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Color(0xFF4285F4),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  GoogleIconWidget(size: 22),
                                  SizedBox(width: 12),
                                  Text(
                                    'تسجيل الدخول عبر Google',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3C4043),
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'ليس لديك حساب عائلي بعد؟',
                      style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ParentRegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'أنشئ حساب عائلة',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      final uri = Uri.parse('https://finfamily-backend.vercel.app/privacy');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: const Text(
                      'سياسة الخصوصية وحماية البيانات',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ForgotPasswordResult {
  final bool openReset;
  final String? sentTo;

  const _ForgotPasswordResult({this.openReset = false, this.sentTo});
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordDialog({required this.initialEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController = TextEditingController(text: widget.initialEmail);
  bool _isSending = false;
  String? _dialogError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _dialogError = 'يرجى إدخال بريد إلكتروني صحيح');
      return;
    }

    setState(() {
      _isSending = true;
      _dialogError = null;
    });

    try {
      await ApiClient().post(
        ApiConfig.forgotPassword,
        data: {'email': email},
      );

      if (!mounted) return;
      Navigator.pop(context, _ForgotPasswordResult(sentTo: email));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _dialogError = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSending,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('استعادة كلمة المرور 🔐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أدخل بريدك الإلكتروني المسجل وسنرسل لك تعليمات إعادة تعيين كلمة المرور.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                hintText: 'name@example.com',
                prefixIcon: const Icon(Icons.email_outlined, size: 20),
                filled: true,
                fillColor: AppTheme.backgroundLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_dialogError != null) ...[
              const SizedBox(height: 8),
              Text(_dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isSending
                    ? null
                    : () => Navigator.pop(context, const _ForgotPasswordResult(openReset: true)),
                child: const Text('لديك رمز استعادة بالفعل؟ اضغط هنا', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSending ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSending ? null : _send,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
            child: _isSending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('إرسال الرابط'),
          ),
        ],
      ),
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog();

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _tokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isResetting = false;
  String? _dialogError;

  @override
  void dispose() {
    _tokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    // Accepts the raw code or the whole pasted link (…/reset-password?token=XYZ)
    final token = extractResetToken(_tokenController.text);
    // Passwords are sent exactly as typed (never trimmed), same as login & register
    final newPass = _newPasswordController.text;
    if (token.isEmpty || newPass.length < 8) {
      setState(() => _dialogError = 'يرجى إدخال الرمز وكلمة مرور من 8 أحرف على الأقل');
      return;
    }

    setState(() {
      _isResetting = true;
      _dialogError = null;
    });

    try {
      await ApiClient().post(
        ApiConfig.resetPassword,
        data: {
          'token': token,
          'new_password': newPass,
        },
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isResetting = false;
        _dialogError = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isResetting,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إعادة تعيين كلمة المرور 🔑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الصق رابط الاستعادة أو الرمز المرسل إلى بريدك الإلكتروني مع كلمة المرور الجديدة:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _tokenController,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'رمز أو رابط الاستعادة',
                hintText: 'الصق الرابط أو الرمز من البريد الإلكتروني',
                filled: true,
                fillColor: AppTheme.backgroundLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                hintText: '8 أحرف على الأقل',
                filled: true,
                fillColor: AppTheme.backgroundLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_dialogError != null) ...[
              const SizedBox(height: 8),
              Text(_dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isResetting ? null : () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isResetting ? null : _reset,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
            child: _isResetting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('تعيين كلمة المرور'),
          ),
        ],
      ),
    );
  }
}
