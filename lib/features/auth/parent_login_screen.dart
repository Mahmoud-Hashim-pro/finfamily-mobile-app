import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth_state.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'parent_register_screen.dart';
import 'mfa_screen.dart';
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

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _emailController.text.trim());
    bool isSending = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
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
                controller: emailController,
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
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    emailController.dispose();
                    Navigator.pop(ctx);
                    _showResetPasswordDialog();
                  },
                  child: const Text('لديك رمز استعادة بالفعل؟ اضغط هنا', style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSending
                  ? null
                  : () {
                      emailController.dispose();
                      Navigator.pop(ctx);
                    },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isSending
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        setDialogState(() => dialogError = 'يرجى إدخال بريد إلكتروني صحيح');
                        return;
                      }

                      setDialogState(() {
                        isSending = true;
                        dialogError = null;
                      });

                      try {
                        await ApiClient().post(
                          ApiConfig.forgotPassword,
                          data: {'email': email},
                        );

                        emailController.dispose();
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم إرسال تعليمات استعادة كلمة المرور إلى $email ✉️'),
                            backgroundColor: AppTheme.emerald,
                          ),
                        );
                      } catch (e) {
                        setDialogState(() {
                          isSending = false;
                          dialogError = ApiErrorHandler.getErrorMessage(e);
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
              child: isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('إرسال الرابط'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResetPasswordDialog() async {
    final tokenController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool isResetting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('إعادة تعيين كلمة المرور 🔑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أدخل رمز الاستعادة المرسل إلى بريدك الإلكتروني مع كلمة المرور الجديدة:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: tokenController,
                decoration: InputDecoration(
                  labelText: 'رمز الاستعادة (Token)',
                  hintText: 'أدخل الرمز أو الصقه',
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  hintText: '8 أحرف على الأقل',
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isResetting ? null : () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: isResetting ? null : () async {
                final token = tokenController.text.trim();
                final newPass = newPasswordController.text.trim();
                if (token.isEmpty || newPass.length < 8) {
                  setDialogState(() => dialogError = 'يرجى إدخال الرمز وكلمة مرور من 8 أحرف على الأقل');
                  return;
                }

                setDialogState(() {
                  isResetting = true;
                  dialogError = null;
                });

                try {
                  await ApiClient().post(
                    ApiConfig.resetPassword,
                    data: {
                      'token': token,
                      'new_password': newPass,
                    },
                  );

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم إعادة تعيين كلمة المرور بنجاح! يمكنك الآن تسجيل الدخول. 🎉'),
                      backgroundColor: AppTheme.emerald,
                    ),
                  );
                } catch (e) {
                  setDialogState(() {
                    isResetting = false;
                    dialogError = ApiErrorHandler.getErrorMessage(e);
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
              child: isResetting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('تعيين كلمة المرور'),
            ),
          ],
        ),
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
    String? email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      email = await _showGoogleEmailPrompt();
      if (email == null || email.trim().isEmpty) return;
    }

    setState(() => _isGoogleLoading = true);

    try {
      final name = email.split('@').first.replaceAll('.', ' ');
      final success = await auth.loginWithGoogle(
        email: email.trim(),
        name: name,
      );

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
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  Future<String?> _showGoogleEmailPrompt() async {
    final promptController = TextEditingController();
    String? dialogError;

    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              _GoogleIconWidget(size: 22),
              SizedBox(width: 10),
              Text(
                'تسجيل الدخول عبر Google',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أدخل بريدك الإلكتروني لدى Google / Gmail للمتابعة فوراً إلى حسابك العائلي:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: promptController,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'بريد Google / Gmail',
                  hintText: 'name@gmail.com',
                  prefixIcon: const Icon(Icons.account_circle_outlined, size: 20),
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = promptController.text.trim();
                if (text.isEmpty || !text.contains('@')) {
                  setDialogState(() => dialogError = 'يرجى إدخال بريد إلكتروني صحيح');
                  return;
                }
                Navigator.pop(ctx, text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navy,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('متابعة'),
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
                                  _GoogleIconWidget(size: 22),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleIconWidget extends StatelessWidget {
  final double size;
  const _GoogleIconWidget({this.size = 24});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h / 2;
    final double strokeWidth = w * 0.22;
    final double radius = (w - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Blue arc
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.4, 1.2, false, paint);

    // Blue horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(cx, cy), Offset(cx + radius + strokeWidth / 2, cy), barPaint);

    // Green arc (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.8, 1.5, false, paint);

    // Yellow arc (bottom-left to left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.3, 1.3, false, paint);

    // Red arc (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.6, 1.5, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
