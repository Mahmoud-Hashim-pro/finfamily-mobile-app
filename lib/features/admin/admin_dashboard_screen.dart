import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../core/api_client.dart';
import '../../core/error_handler.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // Overview data
  Map<String, dynamic>? _overview;
  
  // Cards fleet data
  List<dynamic> _cards = [];
  String _cardSearchQuery = '';

  // Transactions data
  List<dynamic> _transactions = [];

  // DB Health & Security data
  Map<String, dynamic>? _dbHealth;
  Map<String, dynamic>? _securityAlerts;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAllAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllAdminData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final client = ApiClient();
      
      // Parallel fetch of admin data
      final results = await Future.wait([
        client.get(ApiConfig.adminOverview),
        client.get(ApiConfig.adminCards),
        client.get(ApiConfig.adminTransactions),
        client.get(ApiConfig.adminDbHealth),
        client.get(ApiConfig.adminSecurityAlerts),
      ]);

      setState(() {
        _overview = results[0].data;
        _cards = results[1].data['items'] ?? [];
        _transactions = results[2].data['items'] ?? [];
        _dbHealth = results[3].data;
        _securityAlerts = results[4].data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      });
    }
  }

  Future<void> _updateCardStatus(String walletId, String newStatus, String childName) async {
    try {
      await ApiClient().patch(
        '/admin/cards/$walletId/status',
        data: {'card_status': newStatus},
      );

      setState(() {
        final index = _cards.indexWhere((c) => c['wallet_id'] == walletId);
        if (index != -1) {
          _cards[index]['card_status'] = newStatus;
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تعديل حالة كارت $childName إلى $newStatus بنجاح 🛡️'),
          backgroundColor: newStatus == 'active' ? AppTheme.emerald : (newStatus == 'frozen' ? AppTheme.coral : Colors.grey),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1128),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001F54),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Text('👑 ', style: TextStyle(fontSize: 20)),
            Text(
              'لوحة الإدارة والرقابة العليا',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Colors.white),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.gold),
            tooltip: 'تحديث البيانات الحية',
            onPressed: _loadAllAdminData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.gold,
          indicatorWeight: 3,
          labelColor: AppTheme.gold,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.insights, size: 20), text: 'السيولة والمؤشرات'),
            Tab(icon: Icon(Icons.credit_card, size: 20), text: 'أسطول الكروت'),
            Tab(icon: Icon(Icons.receipt_long, size: 20), text: 'العمليات الحية'),
            Tab(icon: Icon(Icons.security, size: 20), text: 'الأمان والداتابيز'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.gold),
                  SizedBox(height: 16),
                  Text('جاري تحميل بيانات الرقابة والسيولة...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.coral, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadAllAdminData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.gold,
                            foregroundColor: AppTheme.navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOverviewTab(),
                    _buildCardsFleetTab(),
                    _buildTransactionsTab(),
                    _buildSecurityAndDbTab(),
                  ],
                ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Overview & Liquidity
  // ---------------------------------------------------------------------------
  Widget _buildOverviewTab() {
    final totals = _overview?['totals'] ?? {};
    final liquidity = _overview?['liquidity'] ?? {};
    final operations = _overview?['operations'] ?? {};

    return RefreshIndicator(
      onRefresh: _loadAllAdminData,
      color: AppTheme.gold,
      backgroundColor: const Color(0xFF0A1128),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Master Liquidity Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.gold.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('إجمالي السيولة المودعة بالنظام 🏦', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('Neon Active 🟢', style: TextStyle(color: AppTheme.emerald, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${liquidity['total_egp'] ?? 0.0} ج.م',
                    style: const TextStyle(
                      color: AppTheme.gold,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('المحافظ الجارية', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text('${liquidity['wallets_balance_egp'] ?? 0.0} ج.م', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('أهداف الادخار', style: TextStyle(color: Colors.white60, fontSize: 11)),
                              const SizedBox(height: 4),
                              Text('${liquidity['savings_balance_egp'] ?? 0.0} ج.م', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Metrics Grid
            const Text('مؤشرات المنصة الحية', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatTile('👨‍👩‍👧‍👦 العائلات', '${totals['families'] ?? 0}', 'عائلة مسجلة'),
                _buildStatTile('👥 المستخدمين', '${totals['users'] ?? 0}', '(${totals['parents'] ?? 0} آباء • ${totals['children'] ?? 0} أطفال)'),
                _buildStatTile('💳 كروت ميزة', '${_overview?['cards']?['total'] ?? 0}', '${_overview?['cards']?['active'] ?? 0} نشطة'),
                _buildStatTile('⚡ سجل العمليات', '${operations['total_records'] ?? 0}', '${operations['completed'] ?? 0} منفذة'),
              ],
            ),
            const SizedBox(height: 20),

            // Operations breakdown
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131D38),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('حالة المعاملات البنكية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniBadge('منفذة ✅', '${operations['completed'] ?? 0}', AppTheme.emerald),
                      _buildMiniBadge('قيد المراجعة ⏳', '${operations['pending'] ?? 0}', AppTheme.gold),
                      _buildMiniBadge('مرفوضة ⛔', '${operations['rejected'] ?? 0}', AppTheme.coral),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Cards Fleet
  // ---------------------------------------------------------------------------
  Widget _buildCardsFleetTab() {
    final filtered = _cards.where((c) {
      if (_cardSearchQuery.isEmpty) return true;
      final q = _cardSearchQuery.toLowerCase();
      final child = (c['child_name'] ?? '').toString().toLowerCase();
      final fam = (c['family_name'] ?? '').toString().toLowerCase();
      final num = (c['card_number'] ?? '').toString().toLowerCase();
      return child.contains(q) || fam.contains(q) || num.contains(q);
    }).toList();

    return RefreshIndicator(
      onRefresh: _loadAllAdminData,
      color: AppTheme.gold,
      backgroundColor: const Color(0xFF0A1128),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              onChanged: (val) => setState(() => _cardSearchQuery = val),
              decoration: InputDecoration(
                hintText: 'ابحث باسم الطفل أو العائلة أو رقم الكارت...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.gold),
                filled: true,
                fillColor: const Color(0xFF131D38),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('لا توجد كروت مطابقة للبحث', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final card = filtered[index];
                      final status = card['card_status'] ?? 'active';
                      final isFrozen = status == 'frozen';
                      final isActive = status == 'active';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131D38),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive
                                ? AppTheme.emerald.withOpacity(0.3)
                                : (isFrozen ? AppTheme.coral.withOpacity(0.3) : Colors.white12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  card['child_name'] ?? 'طفل',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AppTheme.emerald.withOpacity(0.2)
                                        : (isFrozen ? AppTheme.coral.withOpacity(0.2) : Colors.white10),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isActive ? 'نشط 🟢' : (isFrozen ? 'مجمد 🔒' : 'معطل ⛔'),
                                    style: TextStyle(
                                      color: isActive ? AppTheme.emerald : (isFrozen ? AppTheme.coral : Colors.grey),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'عائلة ${card['family_name'] ?? ''} • ${card['card_number'] ?? ''}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('الرصيد: ${card['balance'] ?? 0.0} ج.م', style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
                                Text('الحد اليومي: ${card['daily_limit'] ?? 100} ج.م', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isFrozen)
                                  ElevatedButton.icon(
                                    onPressed: () => _updateCardStatus(card['wallet_id'], 'active', card['child_name']),
                                    icon: const Icon(Icons.lock_open, size: 14),
                                    label: const Text('إلغاء التجميد'),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emerald, foregroundColor: Colors.white),
                                  )
                                else
                                  ElevatedButton.icon(
                                    onPressed: () => _updateCardStatus(card['wallet_id'], 'frozen', card['child_name']),
                                    icon: const Icon(Icons.lock, size: 14),
                                    label: const Text('تجميد الكارت'),
                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.coral, foregroundColor: Colors.white),
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
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Transactions
  // ---------------------------------------------------------------------------
  Widget _buildTransactionsTab() {
    return RefreshIndicator(
      onRefresh: _loadAllAdminData,
      color: AppTheme.gold,
      backgroundColor: const Color(0xFF0A1128),
      child: _transactions.isEmpty
          ? const Center(child: Text('لا توجد عمليات مسجلة بعد في النظام', style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _transactions.length,
              itemBuilder: (context, index) {
                final t = _transactions[index];
                final amt = (t['amount_egp'] as num?)?.toDouble() ?? 0.0;
                final isCompleted = t['status'] == 'completed';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D38),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (amt > 0 ? AppTheme.emerald : AppTheme.blue).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          amt > 0 ? Icons.arrow_downward : Icons.arrow_upward,
                          color: amt > 0 ? AppTheme.emerald : AppTheme.coral,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t['merchant_or_label'] ?? 'معاملة بنكية',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${t['child_name'] ?? ''} (${t['family_name'] ?? ''}) • ${t['created_at']?.toString().split('T').first ?? ''}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${amt > 0 ? '+' : ''}$amt ج.م',
                            style: TextStyle(
                              color: amt > 0 ? AppTheme.emerald : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isCompleted ? 'مكتملة ✅' : 'مرفوضة ⛔',
                            style: TextStyle(color: isCompleted ? AppTheme.emerald : AppTheme.coral, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4: Security Sentinel & DB Health
  // ---------------------------------------------------------------------------
  Widget _buildSecurityAndDbTab() {
    final locked = (_securityAlerts?['locked_accounts'] as List<dynamic>?) ?? [];
    final alerts = (_securityAlerts?['audit_events'] as List<dynamic>?) ?? [];
    final stats = _dbHealth?['table_row_counts'] as Map<String, dynamic>? ?? {};

    return RefreshIndicator(
      onRefresh: _loadAllAdminData,
      color: AppTheme.gold,
      backgroundColor: const Color(0xFF0A1128),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Database Health Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF131D38),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.emerald.withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('سيرفر قاعدة البيانات (Neon DB) 🗄️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('متصل 🟢', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('المزود: ${_dbHealth?['provider'] ?? 'Neon PostgreSQL'}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  Text('زمن الاستجابة (Latency): ${_dbHealth?['latency_ms'] ?? 0} ms', style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.bold)),
                  const Divider(color: Colors.white10, height: 20),
                  const Text('إحصائيات الجداول المباشرة:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: stats.entries.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${e.key}: ${e.value}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    )).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Fraud Radar
            const Text('رادار الحماية من التلاعب والـ Brute-Force 🛡️', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (locked.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: const Color(0xFF131D38), borderRadius: BorderRadius.circular(14)),
                child: const Row(
                  children: [
                    Icon(Icons.verified_user, color: AppTheme.emerald),
                    SizedBox(width: 10),
                    Expanded(child: Text('النظام مؤمن بالكامل — لا توجد حسابات معلقة أو قيد الحظر الأمني حالياً.', style: TextStyle(color: Colors.white70, fontSize: 13))),
                  ],
                ),
              )
            else
              ...locked.map((l) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppTheme.coral.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppTheme.coral)),
                child: Text('حساب مقفول: ${l['full_name']} (${l['family_name']}) - محاولات خاطئة: ${l['failed_attempts']}', style: const TextStyle(color: AppTheme.coral, fontSize: 12)),
              )),

            const SizedBox(height: 20),
            const Text('أحدث سجلات الرقابة الأمنية (Audit Trail)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...alerts.take(10).map((a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF131D38), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.security_update_good, color: Colors.white38, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${a['action']} بواسطة ${a['actor_role']} • ${a['timestamp']?.toString().split('T').first ?? ''}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  Widget _buildStatTile(String title, String val, String sub) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(String label, String count, Color color) {
    return Column(
      children: [
        Text(count, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}
