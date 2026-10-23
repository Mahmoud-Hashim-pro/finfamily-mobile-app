import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../core/api_client.dart';
import '../../core/auth_state.dart';
import '../../core/error_handler.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

/// Normalizes a TOTP code typed by the parent (Arabic-Indic / Persian digits, spaces).
/// Returns the 6 ASCII digits, or null when the input is not a 6-digit code.
@visibleForTesting
String? normalizeTotpInput(String raw) {
  final code = normalizeArabicDigits(raw).replaceAll(RegExp(r'\s'), '');
  return RegExp(r'^\d{6}$').hasMatch(code) ? code : null;
}

/// Second factor for MFA disable / recovery-code regeneration:
/// a 6-digit TOTP → {'code': ...}; a recovery code (8 or 16 letters/digits, case-insensitive,
/// dashes and spaces ignored, e.g. XXXX-XXXX-XXXX-XXXX) → {'recovery_code': normalized}. Null when invalid.
@visibleForTesting
Map<String, String>? buildMfaSecondFactor(String raw) {
  final totp = normalizeTotpInput(raw);
  if (totp != null) return {'code': totp};
  final recovery = normalizeArabicDigits(raw).toUpperCase().replaceAll(RegExp(r'[\s\-‐‑–—]'), '');
  if (RegExp(r'^(?:[A-Z0-9]{8}|[A-Z0-9]{16})$').hasMatch(recovery)) {
    return {'recovery_code': recovery};
  }
  return null;
}

class ParentMfaSettingsScreen extends StatefulWidget {
  const ParentMfaSettingsScreen({super.key});

  @override
  State<ParentMfaSettingsScreen> createState() => _ParentMfaSettingsScreenState();
}

class _ParentMfaSettingsScreenState extends State<ParentMfaSettingsScreen> {
  bool _isLoading = true;
  bool _mfaEnabled = false;
  // Set when /auth/mfa/status failed: the real state is unknown, so no enable/disable controls are shown
  String? _loadError;

  // Setup state
  bool _isSettingUp = false;
  bool _isEnabling = false;
  String? _setupSecret;
  final _totpController = TextEditingController();
  List<String> _recoveryCodes = [];

  @override
  void initState() {
    super.initState();
    _loadMfaStatus();
  }

  @override
  void dispose() {
    _totpController.dispose();
    super.dispose();
  }

  Future<void> _loadMfaStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final res = await ApiClient().get(ApiConfig.mfaStatus);
      final data = res.data;
      if (!mounted) return;
      setState(() {
        _mfaEnabled = data['mfa_enabled'] == true || data['enabled'] == true;
        _loadError = null;
        _isLoading = false;
      });
    } catch (e) {
      // Never guess the status from cached data: show the error with a retry instead
      if (!mounted) return;
      setState(() {
        _loadError = ApiErrorHandler.getErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  /// C13: password accounts confirm with their password (sent exactly as typed — never trimmed, C5);
  /// Google-only accounts (no password) confirm with a fresh Google ID token instead.
  /// Returns null when the Google confirmation was cancelled or failed.
  Future<Map<String, dynamic>?> _identityProof(AuthState auth, bool usesGoogle, String password) async {
    if (!usesGoogle) return {'password': password};
    final idToken = await auth.obtainGoogleIdToken();
    if (idToken == null || idToken.isEmpty) return null;
    return {'google_id_token': idToken};
  }

  String _googleCancelledMessage(AuthState auth) =>
      auth.errorMessage ?? 'لم يتم تأكيد هويتك عبر Google، يرجى المحاولة مرة أخرى';

  Widget _googleConfirmNote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.backgroundLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 18, color: AppTheme.navy),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'حسابك مسجل عبر Google بدون كلمة مرور، سنطلب منك تأكيد هويتك بحساب Google عند المتابعة.',
              style: TextStyle(fontSize: 12, color: AppTheme.navy),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startMfaSetup() async {
    final auth = Provider.of<AuthState>(context, listen: false);
    final usesGoogle = !auth.hasPassword;
    final passwordController = TextEditingController();
    String? dialogError;
    bool isSubmitting = false;

    final data = await showDialog<Map>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          canPop: !isSubmitting,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              usesGoogle ? 'تأكيد هويتك للمتابعة 🔒' : 'تأكيد كلمة المرور للمتابعة 🔒',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  usesGoogle
                      ? 'يرجى تأكيد هويتك عبر Google للبدء في ربط تطبيق التحقق بخطوتين:'
                      : 'يرجى إدخال كلمة مرور حسابك للبدء في ربط تطبيق التحقق بخطوتين:',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),
                if (usesGoogle)
                  _googleConfirmNote()
                else
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الحالية',
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
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  // C5: the password is sent exactly as typed (no trim), like login/register
                  final password = passwordController.text;
                  if (!usesGoogle && password.isEmpty) {
                    setDialogState(() => dialogError = 'أدخل كلمة المرور');
                    return;
                  }
                  setDialogState(() {
                    isSubmitting = true;
                    dialogError = null;
                  });
                  try {
                    final proof = await _identityProof(auth, usesGoogle, password);
                    if (proof == null) {
                      if (!ctx.mounted) return;
                      setDialogState(() {
                        isSubmitting = false;
                        dialogError = _googleCancelledMessage(auth);
                      });
                      return;
                    }
                    final res = await ApiClient().post(ApiConfig.mfaSetup, data: proof);
                    final result = res.data is Map ? res.data as Map : const {};
                    if (ctx.mounted) {
                      Navigator.pop(ctx, result);
                    } else {
                      _onSetupStarted(result);
                    }
                  } catch (e) {
                    if (!ctx.mounted) return;
                    setDialogState(() {
                      isSubmitting = false;
                      dialogError = ApiErrorHandler.getErrorMessage(e);
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(usesGoogle ? 'متابعة مع Google' : 'متابعة'),
              ),
            ],
          ),
        ),
      ),
    );
    passwordController.dispose();
    if (data != null) _onSetupStarted(data);
  }

  void _onSetupStarted(Map data) {
    if (!mounted) return;
    setState(() {
      _isSettingUp = true;
      _setupSecret = (data['secret'] ?? data['secret_key'] ?? '').toString();
      _totpController.clear();
    });
  }

  Future<void> _confirmEnableMfa() async {
    // In-flight guard: a double tap must not send a second /mfa/enable (it fails after the first succeeds)
    if (_isEnabling) return;
    final code = normalizeTotpInput(_totpController.text);
    if (code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل رمز التحقق المكون من 6 أرقام من تطبيق الموثق'),
          backgroundColor: AppTheme.coral,
        ),
      );
      return;
    }

    setState(() => _isEnabling = true);
    try {
      final res = await ApiClient().post(
        ApiConfig.mfaEnable,
        data: {'code': code},
      );
      final rawCodes = ((res.data['codes'] ?? res.data['recovery_codes']) as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];

      if (!mounted) return;
      setState(() {
        _mfaEnabled = true;
        _isSettingUp = false;
        _recoveryCodes = rawCodes;
        _totpController.clear();
      });
      // Keep the cached user (mfa_enabled) in sync for other screens
      Provider.of<AuthState>(context, listen: false).refreshCurrentUser();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تفعيل التحقق بخطوتين (2FA) بنجاح! 🔒'),
          backgroundColor: AppTheme.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorHandler.getErrorMessage(e)),
          backgroundColor: AppTheme.coral,
        ),
      );
    } finally {
      if (mounted) setState(() => _isEnabling = false);
    }
  }

  Future<void> _disableMfa() async {
    final auth = Provider.of<AuthState>(context, listen: false);
    final usesGoogle = !auth.hasPassword;
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    // Not dismissible while a request runs, and the result is applied by this State (not the dialog),
    // so a successful server change is never thrown away
    final disabled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          canPop: !isSubmitting,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('تعطيل التحقق بخطوتين ⚠️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usesGoogle
                        ? 'أدخل رمز التحقق (أو كود الاستعادة) ثم أكد هويتك عبر Google لتأكيد التعطيل:'
                        : 'أدخل كلمة المرور الحالية ورمز التحقق (أو كود الاستعادة) لتأكيد التعطيل:',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (usesGoogle)
                    _googleConfirmNote()
                  else
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        filled: true,
                        fillColor: AppTheme.backgroundLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'رمز التحقق (6 أرقام) أو كود الاستعادة',
                      hintText: '123456 أو XXXX-XXXX-XXXX-XXXX',
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
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  // C5: the password is sent exactly as typed (no trim)
                  final password = passwordController.text;
                  final rawCode = codeController.text;
                  if ((!usesGoogle && password.isEmpty) || rawCode.trim().isEmpty) {
                    setDialogState(() => dialogError = usesGoogle
                        ? 'يرجى إدخال رمز التحقق'
                        : 'يرجى إدخال كلمة المرور ورمز التحقق');
                    return;
                  }
                  final secondFactor = buildMfaSecondFactor(rawCode);
                  if (secondFactor == null) {
                    setDialogState(() => dialogError =
                        'أدخل رمز تحقق من 6 أرقام أو كود استعادة بالصيغة XXXX-XXXX-XXXX-XXXX');
                    return;
                  }
                  setDialogState(() {
                    isSubmitting = true;
                    dialogError = null;
                  });

                  try {
                    final proof = await _identityProof(auth, usesGoogle, password);
                    if (proof == null) {
                      if (!ctx.mounted) return;
                      setDialogState(() {
                        isSubmitting = false;
                        dialogError = _googleCancelledMessage(auth);
                      });
                      return;
                    }
                    await ApiClient().post(ApiConfig.mfaDisable, data: {...proof, ...secondFactor});
                    if (ctx.mounted) {
                      Navigator.pop(ctx, true);
                    } else {
                      _onMfaDisabled();
                    }
                  } catch (e) {
                    if (!ctx.mounted) return;
                    setDialogState(() {
                      isSubmitting = false;
                      dialogError = ApiErrorHandler.getErrorMessage(e);
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coral),
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('تعطيل'),
              ),
            ],
          ),
        ),
      ),
    );
    passwordController.dispose();
    codeController.dispose();
    if (disabled == true) _onMfaDisabled();
  }

  void _onMfaDisabled() {
    if (!mounted) return;
    setState(() {
      _mfaEnabled = false;
      _isSettingUp = false;
      _recoveryCodes = [];
    });
    // Keep the cached user (mfa_enabled) in sync for other screens
    Provider.of<AuthState>(context, listen: false).refreshCurrentUser();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تعطيل التحقق بخطوتين بنجاح'),
        backgroundColor: AppTheme.navy,
      ),
    );
  }

  Future<void> _regenerateRecoveryCodes() async {
    final auth = Provider.of<AuthState>(context, listen: false);
    final usesGoogle = !auth.hasPassword;
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    // The server deletes the old codes and returns the new ones only once: the dialog cannot be
    // dismissed mid-request and the codes are always handed back to this State
    final codes = await showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => PopScope(
          canPop: !isSubmitting,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('توليد أكواد استعادة جديدة 🔑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usesGoogle
                        ? 'لتوليد أكواد جديدة، أدخل رمز التحقق الحالي من التطبيق ثم أكد هويتك عبر Google:'
                        : 'لتوليد أكواد جديدة، أدخل كلمة المرور ورمز التحقق الحالي من التطبيق:',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  if (usesGoogle)
                    _googleConfirmNote()
                  else
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        filled: true,
                        fillColor: AppTheme.backgroundLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: codeController,
                    decoration: InputDecoration(
                      labelText: 'رمز التحقق (6 أرقام) أو كود استعادة قديم',
                      hintText: '123456 أو XXXX-XXXX-XXXX-XXXX',
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
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : () async {
                  // C5: the password is sent exactly as typed (no trim)
                  final password = passwordController.text;
                  final rawCode = codeController.text;
                  if ((!usesGoogle && password.isEmpty) || rawCode.trim().isEmpty) {
                    setDialogState(() => dialogError = usesGoogle
                        ? 'يرجى إدخال رمز التحقق'
                        : 'يرجى إدخال كلمة المرور ورمز التحقق');
                    return;
                  }
                  final secondFactor = buildMfaSecondFactor(rawCode);
                  if (secondFactor == null) {
                    setDialogState(() => dialogError =
                        'أدخل رمز تحقق من 6 أرقام أو كود استعادة بالصيغة XXXX-XXXX-XXXX-XXXX');
                    return;
                  }
                  setDialogState(() {
                    isSubmitting = true;
                    dialogError = null;
                  });

                  try {
                    final proof = await _identityProof(auth, usesGoogle, password);
                    if (proof == null) {
                      if (!ctx.mounted) return;
                      setDialogState(() {
                        isSubmitting = false;
                        dialogError = _googleCancelledMessage(auth);
                      });
                      return;
                    }
                    final res = await ApiClient().post(
                      ApiConfig.mfaRecoveryRegenerate,
                      data: {...proof, ...secondFactor},
                    );
                    final rawCodes = ((res.data['codes'] ?? res.data['recovery_codes']) as List<dynamic>?)
                            ?.map((e) => e.toString())
                            .toList() ??
                        <String>[];

                    if (ctx.mounted) {
                      Navigator.pop(ctx, rawCodes);
                    } else {
                      _onRecoveryCodesRegenerated(rawCodes);
                    }
                  } catch (e) {
                    if (!ctx.mounted) return;
                    setDialogState(() {
                      isSubmitting = false;
                      dialogError = ApiErrorHandler.getErrorMessage(e);
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('توليد'),
              ),
            ],
          ),
        ),
      ),
    );
    passwordController.dispose();
    codeController.dispose();
    if (codes != null) _onRecoveryCodesRegenerated(codes);
  }

  void _onRecoveryCodesRegenerated(List<String> codes) {
    if (!mounted) return;
    setState(() {
      _recoveryCodes = codes;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم توليد أكواد استعادة جديدة بنجاح! احفظها في مكان آمن 🔑'),
        backgroundColor: AppTheme.emerald,
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final auth = Provider.of<AuthState>(context, listen: false);
    final usesGoogle = !auth.hasPassword;
    final passwordController = TextEditingController();
    final mfaController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppTheme.coral, size: 28),
                SizedBox(width: 8),
                Text('حذف الحساب نهائياً ⚠️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.coral)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'تحذير حرج: سيؤدي هذا الإجراء إلى حذف حسابك وحسابات جميع الأطفال، وإلغاء جميع البطاقات والمحافظ والبيانات المالية نهائياً بدون إمكانية للاسترجاع.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 14),
                  if (dialogError != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: AppTheme.coral.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  if (!usesGoogle)
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة المرور الحالية للتأكيد',
                        prefixIcon: Icon(Icons.lock_outline, color: AppTheme.navy),
                      ),
                    ),
                  if (_mfaEnabled) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: mfaController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: 'رمز التحقق (2FA) أو كود الاستعادة',
                        prefixIcon: Icon(Icons.security, color: AppTheme.emerald),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final pwd = passwordController.text.trim();
                        final mfa = mfaController.text.trim();
                        if (!usesGoogle && pwd.isEmpty) {
                          setDialogState(() => dialogError = 'يرجى إدخال كلمة المرور لتأكيد الحذف');
                          return;
                        }
                        if (_mfaEnabled && mfa.isEmpty) {
                          setDialogState(() => dialogError = 'يرجى إدخال رمز التحقق بخطوتين');
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                          dialogError = null;
                        });

                        try {
                          await ApiClient().delete(
                            '/auth/account',
                            data: {
                              if (!usesGoogle) 'password': pwd,
                              if (_mfaEnabled) 'totp_code': mfa,
                            },
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (!mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حذف الحساب والبيانات العائلية نهائياً 👋'),
                              backgroundColor: AppTheme.navy,
                            ),
                          );

                          await auth.logout();
                          if (mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() {
                              isSubmitting = false;
                              dialogError = ApiErrorHandler.getErrorMessage(e);
                            });
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coral),
                child: isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('حذف الحساب نهائياً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    } finally {
      passwordController.dispose();
      mfaController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('إعدادات الأمان (2FA) 🔒'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.navy))
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.coral, size: 48),
                          const SizedBox(height: 12),
                          const Text(
                            'تعذر التحقق من حالة التحقق بخطوتين',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _loadError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.coral, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          CustomButton(
                            text: 'إعادة المحاولة',
                            backgroundColor: AppTheme.navy,
                            onPressed: _loadMfaStatus,
                          ),
                        ],
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Header Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _mfaEnabled
                                      ? AppTheme.emerald.withOpacity(0.12)
                                      : AppTheme.coral.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _mfaEnabled ? Icons.verified_user : Icons.gpp_maybe,
                                  color: _mfaEnabled ? AppTheme.emerald : AppTheme.coral,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _mfaEnabled ? 'التحقق بخطوتين مفعّل 🔒' : 'التحقق بخطوتين معطّل ⚠️',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppTheme.navy,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _mfaEnabled
                                          ? 'حسابك العائلي محمي بواسطة تطبيق المصادقة'
                                          : 'قم بتفعيل 2FA لضمان حماية عمليات الشنطة والمحفظة العائلية',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (!_mfaEnabled && !_isSettingUp) ...[
                          // Enable Action
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'خطوات تفعيل التحقق بخطوتين:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  '1. تحميل تطبيق موثق مثل Google Authenticator أو Microsoft Authenticator.\n2. الضغط على زر "بدء التفعيل" ونسخ المفتاح السري.\n3. إدخال الرمز المكون من 6 أرقام لتأكيد الربط.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5),
                                ),
                                const SizedBox(height: 16),
                                CustomButton(
                                  text: 'بدء تفعيل التحقق بخطوتين (2FA)',
                                  backgroundColor: AppTheme.emerald,
                                  onPressed: _startMfaSetup,
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (_isSettingUp && _setupSecret != null) ...[
                          // Setup Step Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.emerald.withOpacity(0.5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'إعداد تطبيق المصادقة:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.navy),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'انسخ المفتاح السري التالي وأضفه في تطبيق Google Authenticator يدوياً:',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.backgroundLight,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.cardBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: SelectableText(
                                          _setupSecret!,
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.5,
                                            color: AppTheme.navy,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 20, color: AppTheme.navy),
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: _setupSecret!));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('تم نسخ المفتاح السري للحافظة 📋'),
                                              duration: Duration(seconds: 2),
                                            ),
                                          );
                                        },
                                        tooltip: 'نسخ المفتاح',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'أدخل الرمز الحالي من التطبيق (6 أرقام):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _totpController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  decoration: InputDecoration(
                                    hintText: '123456',
                                    filled: true,
                                    fillColor: AppTheme.backgroundLight,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: _isEnabling ? null : () => setState(() => _isSettingUp = false),
                                        child: const Text('إلغاء'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isEnabling ? null : _confirmEnableMfa,
                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                                        child: _isEnabling
                                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Text('تأكيد وتفعيل'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],

                        if (_mfaEnabled) ...[
                          // MFA Enabled Options
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'أكواد استعادة الطوارئ (Recovery Codes):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navy),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'تستخدم هذه الأكواد لتسجيل الدخول في حال فقدت هاتفك أو تطبيق الموثق.',
                                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                                const SizedBox(height: 14),
                                if (_recoveryCodes.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppTheme.backgroundLight,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppTheme.cardBorder),
                                    ),
                                    child: Column(
                                      children: [
                                        for (var code in _recoveryCodes)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  code,
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.navy,
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.copy, size: 16),
                                                  onPressed: () {
                                                    Clipboard.setData(ClipboardData(text: code));
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('تم نسخ $code')),
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                                OutlinedButton.icon(
                                  onPressed: _regenerateRecoveryCodes,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  label: const Text('توليد أكواد استعادة جديدة'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.navy,
                                    side: const BorderSide(color: AppTheme.navy),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Divider(),
                                const SizedBox(height: 12),
                                CustomButton(
                                  text: 'تعطيل التحقق بخطوتين (2FA)',
                                  backgroundColor: AppTheme.coral,
                                  onPressed: _disableMfa,
                                ),
                              ],
                        const SizedBox(height: 24),
                        // Danger Zone: Delete Account
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.coral.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.delete_forever, color: AppTheme.coral, size: 22),
                                  SizedBox(width: 8),
                                  Text(
                                    'منطقة الخطر (Danger Zone)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.coral),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'حذف حساب ولي الأمر وجميع بيانات العائلة نهائياً وفقاً لسياسة الخصوصية وحماية البيانات.',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _showDeleteAccountDialog,
                                icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.coral),
                                label: const Text('حذف حساب العائلة نهائياً', style: TextStyle(color: AppTheme.coral, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppTheme.coral),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }
}
