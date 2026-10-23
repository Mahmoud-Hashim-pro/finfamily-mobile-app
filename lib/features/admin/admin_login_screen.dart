import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../core/auth_state.dart';
import '../auth/auth_input_utils.dart';
import 'admin_dashboard_screen.dart';

/// Decodes a `data:image/png;base64,...` QR data URI returned by /admin/auth/login (null when absent/invalid).
Uint8List? decodeQrDataUri(String? dataUri) {
  if (dataUri == null || dataUri.trim().isEmpty) return null;
  try {
    final bytes = base64Decode(dataUri.split(',').last.trim());
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaCodeController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Step 2: mandatory admin MFA (challenge or first-time enrollment)
  bool _mfaStep = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mfaCodeController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthState>(context, listen: false);
    final success = await auth.loginAdmin(email, password);

    if (!mounted) {
      // Screen left while the password step was in flight: drop the pending MFA temp token
      if (auth.adminMfaPending) auth.cancelAdminMfa();
      return;
    }

    if (success) {
      await _completeAdminLogin(auth);
    } else if (auth.status == AuthStatus.requiresMfa && auth.adminMfaPending) {
      // Password accepted; a password alone never grants admin access → TOTP challenge / enrollment
      setState(() {
        _isLoading = false;
        _mfaStep = true;
        _errorMessage = null;
        _mfaCodeController.clear();
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = auth.errorMessage ?? 'فشل تسجيل الدخول: تأكد من صحة البيانات وصلاحيات الأدمن';
      });
    }
  }

  Future<void> _handleVerifyMfa() async {
    final auth = Provider.of<AuthState>(context, listen: false);
    final enrollment = auth.adminMfaEnrollmentRequired;

    // 6-digit TOTP (Arabic-Indic digits accepted) or, for an enrolled admin, a recovery code
    String? code;
    final totp = normalizeNumericCode(_mfaCodeController.text);
    if (isSixDigitCode(totp)) {
      code = totp;
    } else if (!enrollment) {
      final recovery = normalizeRecoveryCode(_mfaCodeController.text);
      if (isValidRecoveryCode(recovery)) code = recovery;
    }

    if (code == null) {
      setState(() {
        _errorMessage = enrollment
            ? 'أدخل الرمز المكون من 6 أرقام الظاهر في تطبيق المصادقة'
            : 'أدخل رمز التحقق المكون من 6 أرقام أو كود استعادة بالصيغة XXXX-XXXX-XXXX-XXXX';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await auth.verifyAdminMfa(code);

    if (!mounted) return;

    if (success) {
      await _completeAdminLogin(auth);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = auth.errorMessage ?? 'رمز التحقق غير صحيح، حاول مرة أخرى';
        // Temp token expired/invalidated: restart from the password step
        if (!auth.adminMfaPending) {
          _mfaStep = false;
          _mfaCodeController.clear();
        }
      });
    }
  }

  /// Shows freshly issued recovery codes once (enrollment), then opens the admin dashboard.
  Future<void> _completeAdminLogin(AuthState auth) async {
    final codes = List<String>.from(auth.adminRecoveryCodes ?? const <String>[]);
    if (codes.isNotEmpty) {
      await _showRecoveryCodesDialog(codes);
      auth.clearAdminRecoveryCodes();
      if (!mounted) return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
    );
  }

  Future<void> _showRecoveryCodesDialog(List<String> codes) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF131D38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'أكواد استعادة الطوارئ 🔑',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'احفظ هذه الأكواد في مكان آمن الآن. لن تظهر مرة أخرى، وكل كود يُستخدم مرة واحدة فقط إذا فقدت تطبيق المصادقة.',
                  style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 14),
                for (final code in codes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: SelectableText(
                      code,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.gold,
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: codes.join('\n')));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم نسخ أكواد الاستعادة للحافظة 📋'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 16, color: Colors.white70),
              label: const Text('نسخ الكل', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.gold,
                foregroundColor: const Color(0xFF0A1128),
              ),
              child: const Text('حفظتها، متابعة'),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelMfa() {
    Provider.of<AuthState>(context, listen: false).cancelAdminMfa();
    setState(() {
      _mfaStep = false;
      _isLoading = false;
      _errorMessage = null;
      _mfaCodeController.clear();
    });
  }

  Future<void> _openInAuthenticator(String provisioningUri) async {
    try {
      final uri = Uri.parse(provisioningUri);
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('no handler');
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'لم يتم العثور على تطبيق مصادقة على هذا الجهاز، انسخ المفتاح السري وأضفه يدوياً');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);

    return PopScope(
      // While on the MFA step, "back" returns to the password step and clears the temp token
      canPop: !_mfaStep,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mfaStep && !_isLoading) _cancelMfa();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A1128),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon & Title
                  Center(
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.gold, width: 2),
                      ),
                      child: Center(
                        child: Text(_mfaStep ? '🔐' : '👑', style: const TextStyle(fontSize: 32)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      _mfaStep ? 'التحقق الإلزامي بخطوتين' : 'لوحة الإدارة والرقابة العليا',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      _mfaStep
                          ? 'الوصول لصلاحيات الإدارة يتطلب رمز تطبيق المصادقة'
                          : 'تسجيل دخول أعضاء الإدارة المركزية وفريق العمل',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error Banner
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.coral.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.coral, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppTheme.coral, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),

                  if (_mfaStep) ..._buildMfaStep(auth) else ..._buildCredentialsStep(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCredentialsStep() {
    return [
      // Email field
      const Text('البريد الإلكتروني المعتمد للأدمن', style: TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 8),
      TextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'admin@finfamily.com',
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.gold),
          filled: true,
          fillColor: const Color(0xFF131D38),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 16),

      // Password field
      const Text('كلمة المرور', style: TextStyle(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 8),
      TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: '••••••••••••',
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.gold),
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
          filled: true,
          fillColor: const Color(0xFF131D38),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      const SizedBox(height: 28),

      // Submit Button
      ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gold,
          foregroundColor: const Color(0xFF0A1128),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A1128)),
              )
            : const Text(
                'تسجيل الدخول كـ Super Admin 🛡️',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
    ];
  }

  List<Widget> _buildMfaStep(AuthState auth) {
    final enrollment = auth.adminMfaEnrollmentRequired;
    final secret = auth.adminMfaSecret;
    final provisioningUri = auth.adminMfaProvisioningUri;
    final qrBytes = decodeQrDataUri(auth.adminMfaQrCode);

    return [
      if (enrollment) ...[
        // First admin sign-in: mandatory authenticator enrollment
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF131D38),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'تفعيل تطبيق المصادقة (إلزامي لحسابات الإدارة):',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              const Text(
                'امسح رمز QR بتطبيق Google/Microsoft Authenticator، أو أضف المفتاح السري يدوياً، ثم أدخل الرمز المكون من 6 أرقام.',
                style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
              ),
              if (qrBytes != null) ...[
                const SizedBox(height: 14),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Image.memory(
                      qrBytes,
                      width: 180,
                      height: 180,
                      gaplessPlayback: true,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
              if (secret != null && secret.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text('المفتاح السري:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          secret,
                          style: const TextStyle(
                            color: AppTheme.gold,
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18, color: Colors.white70),
                        tooltip: 'نسخ المفتاح',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: secret));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم نسخ المفتاح السري للحافظة 📋'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
              if (provisioningUri != null && provisioningUri.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _openInAuthenticator(provisioningUri),
                  icon: const Icon(Icons.open_in_new, size: 16, color: AppTheme.gold),
                  label: const Text(
                    'فتح في تطبيق المصادقة على هذا الجهاز',
                    style: TextStyle(color: AppTheme.gold, fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],

      // Code field
      Text(
        enrollment ? 'رمز التحقق (6 أرقام)' : 'رمز التحقق (6 أرقام) أو كود الاستعادة',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _mfaCodeController,
        keyboardType: enrollment ? TextInputType.number : TextInputType.visiblePassword,
        textCapitalization: TextCapitalization.characters,
        autocorrect: false,
        enableSuggestions: false,
        style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
        decoration: InputDecoration(
          hintText: enrollment ? '123456' : '123456 أو XXXX-XXXX-XXXX-XXXX',
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: const Icon(Icons.verified_user_outlined, color: AppTheme.gold),
          filled: true,
          fillColor: const Color(0xFF131D38),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        onSubmitted: (_) {
          if (!_isLoading) _handleVerifyMfa();
        },
      ),
      const SizedBox(height: 28),

      ElevatedButton(
        onPressed: _isLoading ? null : _handleVerifyMfa,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.gold,
          foregroundColor: const Color(0xFF0A1128),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0A1128)),
              )
            : Text(
                enrollment ? 'تفعيل ودخول لوحة الإدارة 🛡️' : 'تأكيد ودخول لوحة الإدارة 🛡️',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: _isLoading ? null : _cancelMfa,
        child: const Text('رجوع لتسجيل الدخول', style: TextStyle(color: Colors.white60)),
      ),
    ];
  }
}
