import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../core/auth_state.dart';
import '../../core/error_handler.dart';
import '../../widgets/custom_button.dart';

class ParentMfaSettingsScreen extends StatefulWidget {
  const ParentMfaSettingsScreen({super.key});

  @override
  State<ParentMfaSettingsScreen> createState() => _ParentMfaSettingsScreenState();
}

class _ParentMfaSettingsScreenState extends State<ParentMfaSettingsScreen> {
  bool _isLoading = true;
  bool _mfaEnabled = false;

  // Setup state
  bool _isSettingUp = false;
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
    });

    try {
      final res = await ApiClient().get('/auth/mfa/status');
      final data = res.data;
      if (!mounted) return;
      setState(() {
        _mfaEnabled = data['mfa_enabled'] == true || data['enabled'] == true;
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to authState user object if endpoint fails
      final auth = Provider.of<AuthState>(context, listen: false);
      if (!mounted) return;
      setState(() {
        _mfaEnabled = auth.user?['mfa_enabled'] == true;
        _isLoading = false;
      });
    }
  }

  Future<void> _startMfaSetup() async {
    final passwordController = TextEditingController();
    String? dialogError;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تأكيد كلمة المرور للمتابعة 🔒', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'يرجى إدخال كلمة مرور حسابك للبدء في ربط تطبيق التحقق بخطوتين:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
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
                final password = passwordController.text.trim();
                if (password.isEmpty) {
                  setDialogState(() => dialogError = 'أدخل كلمة المرور');
                  return;
                }
                setDialogState(() {
                  isSubmitting = true;
                  dialogError = null;
                });
                try {
                  final res = await ApiClient().post('/auth/mfa/setup', data: {'password': password});
                  final data = res.data;
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);

                  if (!mounted) return;
                  setState(() {
                    _isSettingUp = true;
                    _setupSecret = data['secret'] ?? data['secret_key'] ?? '';
                    _totpController.clear();
                  });
                } catch (e) {
                  setDialogState(() {
                    isSubmitting = false;
                    dialogError = ApiErrorHandler.getErrorMessage(e);
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('متابعة'),
            ),
          ],
        ),
      ),
    );
    passwordController.dispose();
  }

  Future<void> _confirmEnableMfa() async {
    final code = _totpController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أدخل رمز التحقق المكون من 6 أرقام من تطبيق الموثق'),
          backgroundColor: AppTheme.coral,
        ),
      );
      return;
    }

    try {
      final res = await ApiClient().post(
        '/auth/mfa/enable',
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
    }
  }

  Future<void> _disableMfa() async {
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تعطيل التحقق بخطوتين ⚠️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'أدخل كلمة المرور الحالية ورمز التحقق (أو كود الاستعادة) لتأكيد التعطيل:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
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
                  hintText: '123456 أو XXXX-XXXX',
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
                final password = passwordController.text.trim();
                final code = codeController.text.trim();
                if (password.isEmpty || code.isEmpty) {
                  setDialogState(() => dialogError = 'يرجى إدخال كلمة المرور ورمز التحقق');
                  return;
                }
                setDialogState(() {
                  isSubmitting = true;
                  dialogError = null;
                });

                try {
                  final Map<String, dynamic> body = {'password': password};
                  if (code.contains('-') || code.length > 6) {
                    body['recovery_code'] = code;
                  } else {
                    body['code'] = code;
                  }
                  await ApiClient().post('/auth/mfa/disable', data: body);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);

                  if (!mounted) return;
                  setState(() {
                    _mfaEnabled = false;
                    _recoveryCodes = [];
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تعطيل التحقق بخطوتين بنجاح'),
                      backgroundColor: AppTheme.navy,
                    ),
                  );
                } catch (e) {
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
    );
  }

  Future<void> _regenerateRecoveryCodes() async {
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('توليد أكواد استعادة جديدة 🔑', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'لتوليد أكواد جديدة، أدخل كلمة المرور ورمز التحقق الحالي من التطبيق:',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
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
                  hintText: '123456 أو XXXX-XXXX',
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
                final password = passwordController.text.trim();
                final code = codeController.text.trim();
                if (password.isEmpty || code.isEmpty) {
                  setDialogState(() => dialogError = 'يرجى إدخال كلمة المرور ورمز التحقق');
                  return;
                }
                setDialogState(() {
                  isSubmitting = true;
                  dialogError = null;
                });

                try {
                  final Map<String, dynamic> body = {'password': password};
                  if (code.contains('-') || code.length > 6) {
                    body['recovery_code'] = code;
                  } else {
                    body['code'] = code;
                  }
                  final res = await ApiClient().post('/auth/mfa/recovery-codes/regenerate', data: body);
                  final rawCodes = ((res.data['codes'] ?? res.data['recovery_codes']) as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [];

                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);

                  if (!mounted) return;
                  setState(() {
                    _recoveryCodes = rawCodes;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم توليد أكواد استعادة جديدة بنجاح! احفظها في مكان آمن 🔑'),
                      backgroundColor: AppTheme.emerald,
                    ),
                  );
                } catch (e) {
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
    );
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
                                    onPressed: () => setState(() => _isSettingUp = false),
                                    child: const Text('إلغاء'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _confirmEnableMfa,
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
                                    child: const Text('تأكيد وتفعيل'),
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
