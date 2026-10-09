import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';
import '../../core/error_handler.dart';
import '../../widgets/custom_button.dart';
import 'family_members_screen.dart';

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

  double _dailyLimit = 100.0;
  double _weeklyLimit = 500.0;
  double _monthlyLimit = 1500.0;

  final Map<String, bool> _blockedCategories = {
    'gaming': true,
    'fast_food': false,
    'online_shopping': false,
    'entertainment': false,
    'subscriptions': true,
  };

  final Map<String, String> _categoryLabels = {
    'gaming': 'ألعاب الفيديو والشحن الإلكتروني 🎮',
    'fast_food': 'الوجبات السريعة والمطاعم 🍔',
    'online_shopping': 'المشتريات والتسوق أونلاين 🛍️',
    'entertainment': 'السينما والترفيه 🎬',
    'subscriptions': 'التطبيقات والاشتراكات الشهرية 📱',
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get(ApiConfig.familyOverview);
      final raw = (res.data['children'] as List<dynamic>?) ?? [];
      _children = raw;

      if (_children.isNotEmpty) {
        _selectedChildId = widget.initialChildId ?? _children.first['id']?.toString();
        await _loadChildWallet(_selectedChildId!);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  Future<void> _loadChildWallet(String childId) async {
    try {
      final res = await ApiClient().get('/wallet/child/$childId');
      final data = res.data;

      setState(() {
        _dailyLimit = ((data['daily_limit'] ?? 100.0) as num).toDouble();
        _weeklyLimit = ((data['weekly_limit'] ?? 500.0) as num).toDouble();
        _monthlyLimit = ((data['monthly_limit'] ?? 1500.0) as num).toDouble();

        final blockedList = (data['blocked_categories'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        for (var key in _blockedCategories.keys) {
          _blockedCategories[key] = blockedList.contains(key);
        }
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveLimits() async {
    if (_selectedChildId == null) return;

    setState(() => _isSaving = true);

    try {
      final blocked = _blockedCategories.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toList();

      await ApiClient().patch(
        '/wallet/child/$_selectedChildId/limits',
        data: {
          'daily_limit': _dailyLimit,
          'weekly_limit': _weeklyLimit,
          'monthly_limit': _monthlyLimit,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('حدود الصرف وحظر الفئات'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.coral, size: 48),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.coral)),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _loadData, child: const Text('إعادة المحاولة')),
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
                                            Text(c['avatar'] ?? '👦'),
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
                                          'الحدود تمنع المعاملات تلقائياً عبر شبكة ميزة إذا تجاوز الطفل سقف المصروف المحدد.',
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
                            ),
                            const SizedBox(height: 12),

                            _buildLimitCard(
                              title: 'الحد الأقصى الأسبوعي',
                              value: _weeklyLimit,
                              max: 2000,
                              onChanged: (v) => setState(() => _weeklyLimit = v),
                            ),
                            const SizedBox(height: 12),

                            _buildLimitCard(
                              title: 'الحد الأقصى الشهري',
                              value: _monthlyLimit,
                              max: 5000,
                              onChanged: (v) => setState(() => _monthlyLimit = v),
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
                              backgroundColor: AppTheme.navy,
                              isLoading: _isSaving,
                              onPressed: _saveLimits,
                            ),
                          ],
                        ),
                      ),
      ),
    );
  }

  Widget _buildLimitCard({
    required String title,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
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
              Text(
                '${value.toInt()} ج.م',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: AppTheme.navy,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(20.0, max),
            min: 20,
            max: max,
            divisions: 20,
            activeColor: AppTheme.navy,
            inactiveColor: AppTheme.navy.withOpacity(0.1),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
