import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import '../../widgets/custom_button.dart';

class CreateChoreDialog extends StatefulWidget {
  final List<dynamic>? preloadedChildren;
  final VoidCallback? onChoreCreated;

  const CreateChoreDialog({
    super.key,
    this.preloadedChildren,
    this.onChoreCreated,
  });

  static Future<void> show(BuildContext context, {List<dynamic>? preloadedChildren, VoidCallback? onChoreCreated}) {
    return showDialog(
      context: context,
      builder: (ctx) => CreateChoreDialog(
        preloadedChildren: preloadedChildren,
        onChoreCreated: onChoreCreated,
      ),
    );
  }

  @override
  State<CreateChoreDialog> createState() => _CreateChoreDialogState();
}

class _CreateChoreDialogState extends State<CreateChoreDialog> {
  final _titleController = TextEditingController();
  final _rewardController = TextEditingController(text: '15');
  final _descController = TextEditingController();

  List<dynamic> _children = [];
  String? _selectedChildId;
  String _selectedCategory = 'cleaning';
  String _selectedIcon = '🧹';
  String _selectedDueLabel = 'اليوم';
  bool _isLoadingChildren = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  final List<Map<String, String>> _categories = [
    {'id': 'cleaning', 'label': 'تنظيف وترتيب', 'icon': '🧹'},
    {'id': 'study', 'label': 'دراسة ومذاكرة', 'icon': '📚'},
    {'id': 'routine', 'label': 'عادات وسلوك', 'icon': '🛏️'},
    {'id': 'helping', 'label': 'مساعدة العائلة', 'icon': '🛒'},
  ];

  final List<String> _icons = ['🧹', '🛏️', '📚', '🎒', '🧽', '🌱', '🐕', '⭐', '🏆'];
  final List<String> _dueLabels = ['اليوم', 'غداً', 'نهاية الأسبوع', 'خلال أسبوع'];

  @override
  void initState() {
    super.initState();
    if (widget.preloadedChildren != null && widget.preloadedChildren!.isNotEmpty) {
      _children = widget.preloadedChildren!;
      _selectedChildId = _children.first['id']?.toString();
      _isLoadingChildren = false;
    } else {
      _loadChildren();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rewardController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadChildren() async {
    try {
      final res = await ApiClient().get(ApiConfig.familyChildren);
      final raw = (res.data is Map && res.data['children'] is List)
          ? res.data['children'] as List
          : (res.data is List ? res.data as List : []);

      if (!mounted) return;
      setState(() {
        _children = raw;
        if (_children.isNotEmpty) {
          _selectedChildId = _children.first['id']?.toString();
        }
        _isLoadingChildren = false;
      });
    } catch (_) {
      try {
        final res = await ApiClient().get(ApiConfig.familyOverview);
        final raw = (res.data['children'] as List<dynamic>?) ?? [];
        if (!mounted) return;
        setState(() {
          _children = raw;
          if (_children.isNotEmpty) {
            _selectedChildId = _children.first['id']?.toString();
          }
          _isLoadingChildren = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoadingChildren = false;
          _errorMessage = ApiErrorHandler.getErrorMessage(e);
        });
      }
    }
  }

  Future<void> _submitChore() async {
    final title = _titleController.text.trim();
    final rewardText = _rewardController.text.trim();
    final reward = double.tryParse(rewardText);

    if (title.isEmpty) {
      setState(() => _errorMessage = 'يرجى كتابة عنوان المهمة المنزلية');
      return;
    }
    if (_selectedChildId == null) {
      setState(() => _errorMessage = 'يرجى اختيار الطفل المخصص له المهمة');
      return;
    }
    if (reward == null || reward <= 0) {
      setState(() => _errorMessage = 'يرجى تحديد مكافأة نقدية صحيحة');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final payload = {
      'assigned_to_id': _selectedChildId,
      'child_id': _selectedChildId,
      'title': title,
      'description': _descController.text.trim(),
      'reward': reward,
      'reward_egp': reward,
      'reward_coins': (reward * 5).toInt(),
      'category': _selectedCategory,
      'icon': _selectedIcon,
      'due_label': _selectedDueLabel,
      'kind': 'chore',
    };

    try {
      try {
        await ApiClient().post('/missions', data: payload);
      } catch (_) {
        await ApiClient().post('/family/missions', data: payload);
      }

      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تمت إضافة مهمة "$title" بنجاح للطفل! 🧹🎉'),
          backgroundColor: AppTheme.emerald,
        ),
      );

      widget.onChoreCreated?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Text('🧹', style: TextStyle(fontSize: 24)),
                    SizedBox(width: 8),
                    Text(
                      'إضافة مهمة منزلية جديدة',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.navy,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.coral.withOpacity(0.3)),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppTheme.coral, fontSize: 12),
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Child Picker
            const Text(
              'تخصيص للطفل:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy),
            ),
            const SizedBox(height: 8),
            if (_isLoadingChildren)
              const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
            else if (_children.isEmpty)
              const Text('لا يوجد أطفال في العائلة', style: TextStyle(color: AppTheme.coral, fontSize: 12))
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedChildId,
                    items: _children.map((c) {
                      final id = c['id']?.toString() ?? '';
                      final name = c['name'] ?? c['full_name'] ?? 'طفل';
                      final avatar = c['avatar'] ?? '👦';
                      return DropdownMenuItem<String>(
                        value: id,
                        child: Row(
                          children: [
                            Text(avatar, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedChildId = val),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Title
            const Text(
              'عنوان المهمة:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'مثال: ترتيب السرير والغرفة، حل واجب الرياضيات',
                filled: true,
                fillColor: AppTheme.backgroundLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.cardBorder)),
              ),
            ),
            const SizedBox(height: 16),

            // Reward
            const Text(
              'المكافأة المالية (ج.م):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rewardController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: 'ج.م',
                filled: true,
                fillColor: AppTheme.backgroundLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [5, 10, 15, 20, 50].map((amt) {
                return ActionChip(
                  label: Text('+$amt ج.م', style: const TextStyle(fontSize: 11)),
                  onPressed: () => setState(() => _rewardController.text = amt.toString()),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Category & Icon
            const Text(
              'أيقونة المهمة:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _icons.map((ic) {
                  final isSel = _selectedIcon == ic;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = ic),
                    child: Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.navy.withOpacity(0.1) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isSel ? AppTheme.navy : AppTheme.cardBorder),
                      ),
                      child: Text(ic, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Due Date
            const Text(
              'موعد الإنجاز المستهدف:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navy),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _dueLabels.map((lbl) {
                final isSel = _selectedDueLabel == lbl;
                return ChoiceChip(
                  label: Text(lbl),
                  selected: isSel,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedDueLabel = lbl);
                  },
                  selectedColor: AppTheme.navy,
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSel ? Colors.white : AppTheme.navy,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Buttons
            CustomButton(
              text: 'إضافة المهمة للطفل 🚀',
              backgroundColor: AppTheme.emerald,
              isLoading: _isSubmitting,
              onPressed: _submitChore,
            ),
          ],
        ),
      ),
    );
  }
}
