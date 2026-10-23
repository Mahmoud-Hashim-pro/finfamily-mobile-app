import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';
import '../../core/error_handler.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'family_members_screen.dart';

/// Prefills the custom-limit field with the exact stored value (150 → "150", 150.75 → "150.75", 150.5 → "150.5"),
/// so confirming the dialog unchanged never truncates the limit.
@visibleForTesting
String formatLimitInput(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  var s = v.toStringAsFixed(2);
  if (s.endsWith('0')) s = s.substring(0, s.length - 1);
  return s;
}

/// Parses a custom limit typed by the parent (Arabic-Indic digits / separators normalized). Null when invalid.
@visibleForTesting
double? parseLimitInput(String raw) {
  final parsed = double.tryParse(normalizeArabicDigits(raw.trim()));
  if (parsed == null || !parsed.isFinite || parsed < 0) return null;
  return parsed;
}

class SpendingLimitsScreen extends StatefulWidget {
  final String? initialChildId;
  const SpendingLimitsScreen({super.key, this.initialChildId});

  @override
  State<SpendingLimitsScreen> createState() => _SpendingLimitsScreenState();
}

class _SpendingLimitsScreenState extends State<SpendingLimitsScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<dynamic> _children = [];
  String? _selectedChildId;

  double? _dailyLimit = 100.0;
  double? _weeklyLimit = 500.0;
  double? _monthlyLimit = 1500.0;

  final Map<String, bool> _blockedCategories = {
    'Gaming': false,
    'Food': false,
    'Shopping': false,
    'Entertainment': false,
    'Electronics': false,
    'Toys': false,
  };

  final Map<String, String> _categoryLabels = {
    'Gaming': 'ألعاب الفيديو والشحن الإلكتروني 🎮',
    'Food': 'الوجبات السريعة والمطاعم 🍔',
    'Shopping': 'المشتريات والتسوق أونلاين 🛍️',
    'Entertainment': 'السينما والترفيه 🎬',
    'Electronics': 'الأجهزة الإلكترونية والتقنية 📱',
    'Toys': 'الألعاب والدمى 🧸',
  };

  Set<String> _otherBlockedCategories = {};
  bool _walletLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get(ApiConfig.familyOverview);
      final raw = (res.data['children'] as List<dynamic>?) ?? [];
      _children = raw;

      if (_children.isNotEmpty) {
        // Keep the requested child (or the current selection on retry) only if it is still in the family
        final wanted = _selectedChildId ?? widget.initialChildId;
        _selectedChildId = (wanted != null && _children.any((c) => c['id']?.toString() == wanted))
            ? wanted
            : _children.first['id']?.toString();
        await _loadChildWallet(_selectedChildId!);
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  Future<void> _loadChildWallet(String childId) async {
    setState(() {
      _walletLoaded = false;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get('/wallet/child/$childId');
      final data = res.data;

      if (!mounted) return;
      setState(() {
        _dailyLimit = data['daily_limit'] != null ? (data['daily_limit'] as num).toDouble() : null;
        _weeklyLimit = data['weekly_limit'] != null ? (data['weekly_limit'] as num).toDouble() : null;
        _monthlyLimit = data['monthly_limit'] != null ? (data['monthly_limit'] as num).toDouble() : null;

        final blockedList = (data['blocked_categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        _otherBlockedCategories = {};
        for (var key in _blockedCategories.keys) {
          _blockedCategories[key] = false;
        }
        for (var cat in blockedList) {
          final match = _blockedCategories.keys.firstWhere(
            (k) => k.toLowerCase() == cat.toLowerCase(),
            orElse: () => '',
          );
          if (match.isNotEmpty) {
            _blockedCategories[match] = true;
          } else {
            _otherBlockedCategories.add(cat);
          }
        }
        _walletLoaded = true;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _walletLoaded = false;
        _isLoading = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  Future<void> _saveLimits() async {
    if (_selectedChildId == null || !_walletLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى انتظار تحميل بيانات حدود الصرف الخاصة بالطفل أولاً.'),
          backgroundColor: AppTheme.coral,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final List<String> blocked = List.from(_otherBlockedCategories);
      for (var entry in _blockedCategories.entries) {
        if (entry.value) {
          blocked.add(entry.key);
        }
      }

      await ApiClient().patch(
        '/wallet/child/$_selectedChildId/limits',
        data: {
          'daily_limit': _dailyLimit ?? -1,
          'weekly_limit': _weeklyLimit ?? -1,
          'monthly_limit': _monthlyLimit ?? -1,
          'blocked_categories': blocked,
        },
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ حدود الصرف وقواعد الأمان بنجاح في قاعدة البيانات! 🔒'),
          backgroundColor: AppTheme.emerald,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorHandler.getErrorMessage(e)),
          backgroundColor: AppTheme.coral,
        ),
      );
    }
  }

  void _showEditLimitDialog({
    required String title,
    required double? currentValue,
    required ValueChanged<double?> onSave,
  }) {
    final controller = TextEditingController(
      text: currentValue != null ? formatLimitInput(currentValue) : '',
    );
    bool isUnlimited = currentValue == null;
    String? inputError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('بدون حد (غير مقيد)', style: TextStyle(fontSize: 14)),
                    value: isUnlimited,
                    activeColor: AppTheme.navy,
                    onChanged: (val) {
                      setDialogState(() {
                        isUnlimited = val ?? false;
                        inputError = null;
                        if (isUnlimited) controller.clear();
                      });
                    },
                  ),
                  if (!isUnlimited) ...[
                    const SizedBox(height: 10),
                    const Text('القيمة المحددة (ج.م):', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) {
                        if (inputError != null) setDialogState(() => inputError = null);
                      },
                      decoration: InputDecoration(
                        hintText: 'مثال: 150 أو 0 لتعطيل الصرف',
                        suffixText: 'ج.م',
                        errorText: inputError,
                        filled: true,
                        fillColor: AppTheme.backgroundLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        ActionChip(
                          label: const Text('0 ج.م (تعطيل الصرف)'),
                          onPressed: () {
                            setDialogState(() {
                              controller.text = '0';
                              inputError = null;
                            });
                          },
                        ),
                        ActionChip(
                          label: const Text('50'),
                          onPressed: () => setDialogState(() {
                            controller.text = '50';
                            inputError = null;
                          }),
                        ),
                        ActionChip(
                          label: const Text('200'),
                          onPressed: () => setDialogState(() {
                            controller.text = '200';
                            inputError = null;
                          }),
                        ),
                        ActionChip(
                          label: const Text('500'),
                          onPressed: () => setDialogState(() {
                            controller.text = '500';
                            inputError = null;
                          }),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (isUnlimited) {
                    onSave(null);
                  } else {
                    final parsed = parseLimitInput(controller.text);
                    if (parsed == null) {
                      // Never ignore Confirm silently: tell the parent what is wrong
                      setDialogState(() => inputError = 'يرجى إدخال قيمة صحيحة (0 أو أكثر)');
                      return;
                    }
                    onSave(parsed);
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy),
                child: const Text('تأكيد'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('حدود الصرف وحظر الفئات'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.navy))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.coral, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadData,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('إعادة المحاولة'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy, foregroundColor: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  )
                : _children.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('🛡️', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 12),
                              const Text(
                                'لا يوجد أطفال في العائلة لضبط حدودهم',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navy),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'أضف أطفالك أولاً لتتمكن من تخصيص حدود الصرف اليومية والشهرية لهم',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.navy,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                onPressed: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyMembersScreen()));
                                  _loadData();
                                },
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('إضافة بطل مالي'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Child selector if multiple children
                            if (_children.length > 1) ...[
                              const Text(
                                'اختر الطفل:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navy),
                              ),
                              const SizedBox(height: 8),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _children.map((c) {
                                    final childId = c['id']?.toString();
                                    final isSelected = _selectedChildId == childId;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedChildId = childId;
                                          _isLoading = true;
                                        });
                                        _loadChildWallet(childId!);
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppTheme.navy : Colors.white,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: isSelected ? AppTheme.navy : AppTheme.cardBorder),
                                        ),
                                        child: Row(
                                          children: [
                                            Text((c['avatar'] ?? c['avatar_url'] ?? '👦').toString()),
                                            const SizedBox(width: 6),
                                            Text(
                                              c['full_name'] ?? 'ابن',
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : AppTheme.navy,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],

                            // Intro
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: const Row(
                                children: [
                                  Text('🛡️', style: TextStyle(fontSize: 32)),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'حماية مالية ذكية لأطفالك',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: AppTheme.navy,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'يمكنك تعيين حدود الصرف أو إلغائها أو وضعها 0 لمنع الشراء تماماً عبر بطاقة ميزة.',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 11,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Sliders Section
                            const Text(
                              'سقوف الصرف المسموحة:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.navy),
                            ),
                            const SizedBox(height: 12),

                            _buildLimitCard(
                              title: 'الحد الأقصى اليومي',
                              value: _dailyLimit,
                              max: 500,
                              onChanged: (v) => setState(() => _dailyLimit = v),
                              onEditCustom: () {
                                _showEditLimitDialog(
                                  title: 'الحد الأقصى اليومي',
                                  currentValue: _dailyLimit,
                                  onSave: (val) => setState(() => _dailyLimit = val),
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            _buildLimitCard(
                              title: 'الحد الأقصى الأسبوعي',
                              value: _weeklyLimit,
                              max: 2000,
                              onChanged: (v) => setState(() => _weeklyLimit = v),
                              onEditCustom: () {
                                _showEditLimitDialog(
                                  title: 'الحد الأقصى الأسبوعي',
                                  currentValue: _weeklyLimit,
                                  onSave: (val) => setState(() => _weeklyLimit = val),
                                );
                              },
                            ),
                            const SizedBox(height: 12),

                            _buildLimitCard(
                              title: 'الحد الأقصى الشهري',
                              value: _monthlyLimit,
                              max: 5000,
                              onChanged: (v) => setState(() => _monthlyLimit = v),
                              onEditCustom: () {
                                _showEditLimitDialog(
                                  title: 'الحد الأقصى الشهري',
                                  currentValue: _monthlyLimit,
                                  onSave: (val) => setState(() => _monthlyLimit = val),
                                );
                              },
                            ),
                            const SizedBox(height: 24),

                            // Category Blocklist
                            const Text(
                              'الفئات المحظورة من الشراء:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.navy),
                            ),
                            const SizedBox(height: 12),

                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              child: Column(
                                children: _blockedCategories.keys.map((catKey) {
                                  final isBlocked = _blockedCategories[catKey] ?? false;
                                  final label = _categoryLabels[catKey] ?? catKey;
                                  return SwitchListTile(
                                    activeColor: AppTheme.coral,
                                    title: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isBlocked ? AppTheme.coral : AppTheme.navy,
                                      ),
                                    ),
                                    value: isBlocked,
                                    onChanged: (val) {
                                      setState(() {
                                        _blockedCategories[catKey] = val;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 28),

                            CustomButton(
                              text: 'حفظ الحدود والإعدادات',
                              backgroundColor: (_walletLoaded && !_isLoading) ? AppTheme.navy : Colors.grey.shade400,
                              isLoading: _isSaving,
                              onPressed: (_walletLoaded && !_isLoading) ? _saveLimits : null,
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildLimitCard({
    required String title,
    required double? value,
    required double max,
    required ValueChanged<double?> onChanged,
    required VoidCallback onEditCustom,
  }) {
    final String displayValue;
    Color valueColor = AppTheme.navy;
    if (value == null) {
      displayValue = 'بدون حد (غير مقيد)';
      valueColor = AppTheme.textSecondary;
    } else if (value == 0) {
      displayValue = '0 ج.م (معطل)';
      valueColor = AppTheme.coral;
    } else {
      displayValue = '${value.toStringAsFixed(2)} ج.م';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              InkWell(
                onTap: onEditCustom,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        displayValue,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: valueColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, size: 14, color: AppTheme.textMuted),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (value != null && value > 0) ...[
            const SizedBox(height: 6),
            Slider(
              value: value.clamp(0.0, max),
              min: 0,
              max: max,
              divisions: 20,
              activeColor: AppTheme.navy,
              inactiveColor: AppTheme.navy.withOpacity(0.1),
              onChanged: onChanged,
            ),
          ] else ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: onEditCustom,
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('تخصيص قيمة الحد أو تغييره'),
                  style: TextButton.styleFrom(foregroundColor: AppTheme.navy),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
