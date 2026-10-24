import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';
import '../../core/auth_state.dart';
import '../../core/error_handler.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

/// Normalizes a child PIN typed by the parent (Arabic-Indic / Persian digits → ASCII).
/// Returns the 6 ASCII digits, or null when the input is not a 6-digit PIN.
@visibleForTesting
String? normalizeChildPin(String raw) {
  final pin = normalizeArabicDigits(raw.trim());
  return RegExp(r'^\d{6}$').hasMatch(pin) ? pin : null;
}

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key, this.refreshSignal});

  /// Bumped by ParentNavShell when the Family tab becomes active (the tab lives in an IndexedStack).
  final ValueNotifier<int>? refreshSignal;

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  String _familyCode = '---';
  String _familyName = '';
  List<dynamic> _children = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_handleRefresh);
    _loadData();
  }

  void _handleRefresh() {
    _loadData();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_handleRefresh);
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final codeRes = await ApiClient().get(ApiConfig.familyCode);
      // /family/overview (parent-only) carries each child's real card_number and avatar
      final childrenRes = await ApiClient().get(ApiConfig.familyOverview);

      if (!mounted) return;
      setState(() {
        _familyCode = codeRes.data['family_code'] ?? '---';
        _familyName = codeRes.data['family_name'] ?? '';
        _children = childrenRes.data['children'] ?? [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  void _showAddChildDialog() {
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    String selectedAvatar = '👦';
    bool isSubmitting = false;
    String? dialogError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      // Drag-to-dismiss pops the sheet directly (PopScope cannot block it); back and barrier taps
      // are blocked by the PopScope below only while the request is in flight
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => PopScope(
          canPop: !isSubmitting,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            // Scrolls on small phones when the keyboard is open, so the create button stays reachable
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'إضافة بطل مالي جديد 🧒',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيتم إنشاء حساب للطفل وتوليد كارت ميزة افتراضي له فوراً',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  if (dialogError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        dialogError!,
                        style: const TextStyle(color: AppTheme.coral, fontSize: 12),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ['👦', '👧', '🦁', '🚀', '⭐'].map((emoji) {
                      final isSelected = selectedAvatar == emoji;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedAvatar = emoji),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.emerald.withOpacity(0.2)
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.emerald
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 26)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  CustomTextField(
                    controller: nameController,
                    label: 'اسم الطفل بالكامل',
                    hint: 'مثلاً: عمر أحمد',
                  ),
                  const SizedBox(height: 12),
                  CustomTextField(
                    controller: pinController,
                    label: 'رمز PIN الخاص به (6 أرقام)',
                    hint: '123456',
                    keyboardType: TextInputType.number,
                    obscureText: true,
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: 'إنشاء حساب الطفل والكارت',
                    backgroundColor: AppTheme.emerald,
                    isLoading: isSubmitting,
                    onPressed: () async {
                      final name = nameController.text.trim();
                      // Arabic-Indic digits are accepted and sent as ASCII (C6)
                      final pin = normalizeChildPin(pinController.text);

                      if (name.isEmpty) {
                        setModalState(() => dialogError = 'يرجى إدخال اسم الطفل');
                        return;
                      }
                      if (pin == null) {
                        setModalState(() =>
                            dialogError = 'رمز الـ PIN يجب أن يتكون من 6 أرقام');
                        return;
                      }

                      setModalState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      try {
                        await ApiClient().post(
                          ApiConfig.createChild,
                          data: {
                            'full_name': name,
                            'pin': pin,
                            'avatar': selectedAvatar,
                          },
                        );

                        // The child now exists: feedback and refresh come from this screen's State,
                        // even if the sheet is no longer on screen
                        if (ctx.mounted) Navigator.pop(ctx);

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content:
                                Text('تم تسجيل $name وتوليد كارت ميزة بنجاح! 💳'),
                            backgroundColor: AppTheme.emerald,
                          ),
                        );

                        _loadData();
                      } catch (e) {
                        if (ctx.mounted) {
                          setModalState(() {
                            isSubmitting = false;
                            dialogError = ApiErrorHandler.getErrorMessage(e);
                          });
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(ApiErrorHandler.getErrorMessage(e)),
                              backgroundColor: AppTheme.coral,
                            ),
                          );
                          _loadData(); // a timeout may still have created the child server-side
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRotateFamilyCode() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تغيير كود العائلة 🔄', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'هل أنت متأكد من تغيير كود العائلة؟ سيتم إلغاء الكود الحالي فوراً وسيتعين على أفراد العائلة استخدام الكود الجديد.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coral),
            child: const Text('تأكيد التغيير', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final res = await ApiClient().post('/auth/family/code/rotate');
      final newCode = res.data['family_code']?.toString() ?? '';
      if (!mounted) return;
      setState(() => _familyCode = newCode);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تغيير كود العائلة بنجاح: $newCode 🔑'),
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

  void _showResetPinDialog(Map child) {
    final pinController = TextEditingController();
    bool isSubmitting = false;
    String? dialogError;
    final childId = (child['id'] ?? '').toString();
    final childName = child['full_name'] ?? child['name'] ?? 'الطفل';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('إعادة تعيين PIN لـ $childName 🔒', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('أدخل رمز PIN جديد مكوّن من 6 أرقام للطفل:', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 12),
              if (dialogError != null)
                Text(dialogError!, style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'رمز PIN الجديد',
                  prefixIcon: Icon(Icons.pin, color: AppTheme.navy),
                ),
              ),
            ],
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
                      final rawPin = pinController.text.trim();
                      final pin = normalizeChildPin(rawPin);
                      if (pin == null) {
                        setDialogState(() => dialogError = 'يجب أن يتكون رمز PIN من 6 أرقام');
                        return;
                      }

                      setDialogState(() {
                        isSubmitting = true;
                        dialogError = null;
                      });

                      try {
                        await ApiClient().post(
                          '/auth/parent/children/$childId/reset-pin',
                          data: {'new_pin': pin},
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('تم إعادة تعيين رمز PIN لـ $childName بنجاح! 🔒'),
                            backgroundColor: AppTheme.emerald,
                          ),
                        );
                      } catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() {
                            isSubmitting = false;
                            dialogError = ApiErrorHandler.getErrorMessage(e);
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald),
              child: isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('حفظ الرمز الجديد'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteChildDialog(Map child) async {
    final childId = (child['id'] ?? '').toString();
    final childName = child['full_name'] ?? child['name'] ?? 'الطفل';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('حذف حساب $childName ⚠️', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.coral)),
        content: Text(
          'هل أنت متأكد تماماً من حذف حساب $childName؟ سيتم حذف جميع بيانات الطفل ومحفظته وبطاقته وسجلاته نهائياً ولا يمكن استرجاعها.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coral),
            child: const Text('نعم، حذف الحساب نهائياً', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ApiClient().delete('/auth/parent/children/$childId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف حساب $childName بنجاح 🗑️'),
          backgroundColor: AppTheme.emerald,
        ),
      );
      _loadData();
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthState>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('أفراد العائلة والكود'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: AppTheme.navy,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.coral.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppTheme.coral.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.coral),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                color: AppTheme.coral, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),

                // Family Code Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2D52), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.navy.withOpacity(0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _familyName.isNotEmpty
                            ? 'كود عائلة $_familyName'
                            : 'كود العائلة الخاص بكم (Family Code)',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _familyCode,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 14),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: _familyCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'تم نسخ كود العائلة إلى الحافظة! 📋'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.copy, color: AppTheme.gold),
                          ),
                          IconButton(
                            tooltip: 'تغيير كود العائلة',
                            onPressed: _confirmRotateFamilyCode,
                            icon: const Icon(Icons.autorenew, color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'أعطِ هذا الكود لأولادك ليسجلوا به في تطبيق الهاتف مع الـ PIN الخاص بهم.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white60, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'أعضاء العائلة المسجلين:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _showAddChildDialog,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة طفل'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Parent Card
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.cardBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppTheme.navy.withOpacity(0.1),
                        child: const Text('👨', style: TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              auth.user?['full_name'] ?? 'ولي الأمر',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'ولي الأمر (المسؤول)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Children List or Empty State
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_children.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        const Text('🧒', style: TextStyle(fontSize: 36)),
                        const SizedBox(height: 8),
                        const Text(
                          'لا يوجد أطفال مسجلون في هذه العائلة بعد',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppTheme.navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'اضغط على زر "إضافة طفل" بالأعلى لإنشاء أول حساب',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _children.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final c = _children[index];
                      // The real (masked) card number from the child's wallet — never derived from the id
                      final cardNumber = c['card_number']?.toString() ?? '';

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor:
                                  AppTheme.emerald.withOpacity(0.12),
                              child: Text((c['avatar'] ?? c['avatar_url'] ?? '👦').toString(),
                                  style: const TextStyle(fontSize: 26)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['full_name'] ?? 'بطل مالي',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'بطل مالي',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  if (cardNumber.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      cardNumber,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppTheme.textMuted,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert, color: AppTheme.navy),
                              onSelected: (val) {
                                if (val == 'reset_pin') {
                                  _showResetPinDialog(c);
                                } else if (val == 'delete_child') {
                                  _showDeleteChildDialog(c);
                                }
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'reset_pin',
                                  child: Row(
                                    children: [
                                      Icon(Icons.lock_reset, size: 18, color: AppTheme.navy),
                                      SizedBox(width: 8),
                                      Text('إعادة تعيين PIN'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete_child',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline, size: 18, color: AppTheme.coral),
                                      SizedBox(width: 8),
                                      Text('حذف الحساب', style: TextStyle(color: AppTheme.coral)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
