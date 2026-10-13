import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';
import 'create_chore_dialog.dart';

enum ApprovalType { mission, cardPurchase }

class ApprovalItem {
  final String id;
  final ApprovalType type;
  final String childId;
  final String childName;
  final String title;
  final String description;
  final double amount;
  final String kind;
  final String? proofText;
  final String? proofUrl;
  final String? category;
  final String? location;

  ApprovalItem({
    required this.id,
    required this.type,
    required this.childId,
    required this.childName,
    required this.title,
    required this.description,
    required this.amount,
    this.kind = 'chore',
    this.proofText,
    this.proofUrl,
    this.category,
    this.location,
  });
}

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  List<ApprovalItem> _pendingApprovals = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all'; // 'all', 'missions', 'purchases'

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  Future<void> _loadApprovals() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch children to map child IDs to names
      final Map<String, String> childNames = {};
      try {
        final childrenRes = await ApiClient().get(ApiConfig.familyChildren);
        final rawChildren = (childrenRes.data is Map && childrenRes.data['children'] is List)
            ? childrenRes.data['children'] as List
            : (childrenRes.data is List ? childrenRes.data as List : []);
        for (var c in rawChildren) {
          if (c is Map) {
            final id = (c['id'] ?? '').toString();
            final name = c['name'] ?? c['full_name'] ?? c['username'] ?? 'الطفل';
            if (id.isNotEmpty) childNames[id] = name.toString();
          }
        }
      } catch (_) {
        // Fallback: Continue without child names lookup
      }

      final List<ApprovalItem> items = [];

      // 2. Fetch submitted missions
      try {
        final missionsRes = await ApiClient().get('/missions/family?status=submitted');
        final rawMissions = (missionsRes.data is List) ? missionsRes.data as List : [];
        for (var m in rawMissions) {
          if (m is Map) {
            final childId = (m['child_id'] ?? m['assigned_to_id'] ?? '').toString();
            final childName = m['child_name'] ?? childNames[childId] ?? 'الطفل';
            final rewardAmount = ((m['reward_egp'] ?? m['reward'] ?? m['reward_amount'] ?? 0.0) as num).toDouble();

            items.add(
              ApprovalItem(
                id: (m['id'] ?? '').toString(),
                type: ApprovalType.mission,
                childId: childId,
                childName: childName,
                title: m['title'] ?? 'مهمة عائلية',
                description: m['description'] ?? '',
                amount: rewardAmount,
                kind: (m['kind'] ?? 'chore').toString(),
                proofText: m['proof_text'] ?? m['proof'],
                proofUrl: m['proof_url'],
              ),
            );
          }
        }
      } catch (e) {
        // If missions fail, record or continue to card purchases
      }

      // 3. Fetch pending card purchases
      try {
        final purchasesRes = await ApiClient().get('/card/purchases/family?status=pending');
        final rawPurchases = (purchasesRes.data is List) ? purchasesRes.data as List : [];
        for (var p in rawPurchases) {
          if (p is Map) {
            final childId = (p['child_id'] ?? '').toString();
            final childName = p['child_name'] ?? childNames[childId] ?? 'الطفل';
            final amount = ((p['amount'] ?? 0.0) as num).toDouble();
            final merchant = p['merchant'] ?? 'مشتريات بطاقة';
            final category = p['category'];
            final location = p['location'];

            String desc = '';
            if (category != null && category.toString().isNotEmpty) {
              desc = 'التصنيف: $category';
            }
            if (location != null && location.toString().isNotEmpty) {
              desc = desc.isNotEmpty ? '$desc | $location' : location.toString();
            }

            items.add(
              ApprovalItem(
                id: (p['id'] ?? '').toString(),
                type: ApprovalType.cardPurchase,
                childId: childId,
                childName: childName,
                title: merchant,
                description: desc,
                amount: amount,
                category: category?.toString(),
                location: location?.toString(),
              ),
            );
          }
        }
      } catch (e) {
        // If purchases fail, keep missions
      }

      if (!mounted) return;
      setState(() {
        _pendingApprovals = items;
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

  Future<void> _handleAction(ApprovalItem item, bool isApproved) async {
    try {
      if (item.type == ApprovalType.cardPurchase) {
        await ApiClient().post(
          '/card/purchases/${item.id}/review',
          data: {
            'decision': isApproved ? 'approve' : 'reject',
          },
        );
      } else {
        await ApiClient().post(
          '/missions/${item.id}/review',
          data: {
            'decision': isApproved ? 'approve' : 'reject',
            'note': isApproved ? 'تمت الموافقة من ولي الأمر' : 'تم الرفض من ولي الأمر',
          },
        );
      }

      if (!mounted) return;
      setState(() {
        _pendingApprovals.removeWhere((i) => i.id == item.id);
      });

      final String successMsg;
      if (item.type == ApprovalType.cardPurchase) {
        successMsg = isApproved
            ? 'تمت الموافقة على عملية الشراء (${item.title}) بقيمة ${item.amount.toStringAsFixed(0)} ج.م 💳'
            : 'تم رفض عملية الشراء (${item.title})';
      } else if (item.kind == 'redemption') {
        successMsg = isApproved
            ? 'تمت الموافقة على طلب استبدال المكافأة "${item.title}" بقيمة ${item.amount.toStringAsFixed(0)} ج.م 🎁'
            : 'تم رفض طلب استبدال المكافأة "${item.title}"';
      } else {
        successMsg = isApproved
            ? 'تمت الموافقة على إنجاز مهمة "${item.title}" وإضافة ${item.amount.toStringAsFixed(0)} ج.م للطفل! 🎉'
            : 'تم رفض طلب إنجاز مهمة "${item.title}"';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: isApproved ? AppTheme.emerald : AppTheme.coral,
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

  List<ApprovalItem> get _filteredApprovals {
    if (_selectedFilter == 'missions') {
      return _pendingApprovals.where((a) => a.type == ApprovalType.mission).toList();
    } else if (_selectedFilter == 'purchases') {
      return _pendingApprovals.where((a) => a.type == ApprovalType.cardPurchase).toList();
    }
    return _pendingApprovals;
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredApprovals;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('الموافقات والمهام (Approvals)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_task),
            tooltip: 'إضافة مهمة منزلية جديدة',
            onPressed: () {
              CreateChoreDialog.show(context, onChoreCreated: _loadApprovals);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          CreateChoreDialog.show(context, onChoreCreated: _loadApprovals);
        },
        backgroundColor: AppTheme.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('مهمة جديدة 🧹'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadApprovals,
          color: AppTheme.navy,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'الطلبات بانتظار موافقتك:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navy,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_pendingApprovals.length} طلبات',
                        style: const TextStyle(
                          color: AppTheme.coral,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('الكل (${_pendingApprovals.length})', 'all'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'مهام منزلية (${_pendingApprovals.where((a) => a.type == ApprovalType.mission).length})',
                        'missions',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'مشتريات بطاقة (${_pendingApprovals.where((a) => a.type == ApprovalType.cardPurchase).length})',
                        'purchases',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.navy))
                      : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
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
                                    onPressed: _loadApprovals,
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('إعادة المحاولة'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.navy,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : filteredList.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.emerald.withOpacity(0.1),
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.done_all, size: 40, color: AppTheme.emerald),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'رائع! لا توجد طلبات معلقة',
                                        style: TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.navy,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'كل طلبات ومهام أطفالك ومشترياتهم تمت مراجعتها بالكامل.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  itemCount: filteredList.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                                  itemBuilder: (context, index) {
                                    final item = filteredList[index];
                                    final isChore = item.type == ApprovalType.mission;

                                    return Container(
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: AppTheme.cardBorder),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.03),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    isChore ? '🧹' : '💳',
                                                    style: const TextStyle(fontSize: 22),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    item.childName,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                      color: AppTheme.navy,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isChore
                                                          ? AppTheme.gold.withOpacity(0.2)
                                                          : AppTheme.navy.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      isChore ? 'مهمة منزلية' : 'مشتريات كارت',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: isChore ? Colors.orange.shade800 : AppTheme.navy,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isChore
                                                      ? AppTheme.emerald.withOpacity(0.12)
                                                      : AppTheme.coral.withOpacity(0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  isChore
                                                      ? '+${item.amount.toStringAsFixed(0)} ج.م'
                                                      : '${item.amount.toStringAsFixed(0)} ج.م',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 13,
                                                    color: isChore ? AppTheme.emerald : AppTheme.coral,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            item.title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (item.description.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              item.description,
                                              style: const TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                          if (item.proofText != null && item.proofText!.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: AppTheme.backgroundLight,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: AppTheme.cardBorder),
                                              ),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.check_circle_outline, size: 16, color: AppTheme.emerald),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      'إثبات الطفل: ${item.proofText!}',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppTheme.navy,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  onPressed: () => _handleAction(item, false),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppTheme.coral,
                                                    side: const BorderSide(color: AppTheme.coral),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.close, size: 16),
                                                  label: const Text('رفض'),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () => _handleAction(item, true),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: AppTheme.emerald,
                                                    foregroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.check, size: 16),
                                                  label: Text(isChore ? 'موافقة وصرف' : 'موافقة على الشراء'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = filterKey;
          });
        }
      },
      selectedColor: AppTheme.navy,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : AppTheme.textSecondary,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.navy : AppTheme.cardBorder,
      ),
    );
  }
}
