import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/api_config.dart';
import '../../core/api_client.dart';
import '../../core/auth_state.dart';
import '../../core/date_utils.dart';
import '../../core/error_handler.dart';
import '../auth/role_select_screen.dart';

/// Display helpers for the admin dashboard, mapped to the fields /api/admin/* actually returns.
class AdminDashboardFormat {
  AdminDashboardFormat._();

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  /// EGP amounts are always shown with exactly 2 decimals (contract C7).
  static String egp(dynamic value) => (_toDouble(value) ?? 0.0).toStringAsFixed(2);

  /// Wallet.daily_limit == null means "no daily limit" on the backend (never a 100 EGP default).
  static String dailyLimit(dynamic value) {
    final limit = _toDouble(value);
    return limit == null ? 'الحد اليومي: بدون حد' : 'الحد اليومي: ${limit.toStringAsFixed(2)} ج.م';
  }

  /// Card purchases are outgoing debits: always rendered with a minus sign.
  static String purchaseAmount(dynamic value) => '-${egp(value)} ج.م';

  /// PurchaseStatus has three values: completed / pending / rejected.
  static String purchaseStatusLabel(dynamic status) {
    switch (status?.toString()) {
      case 'completed':
        return 'مكتملة ✅';
      case 'pending':
        return 'قيد المراجعة ⏳';
      case 'rejected':
        return 'مرفوضة ⛔';
      default:
        return status?.toString() ?? '';
    }
  }

  static Color purchaseStatusColor(dynamic status) {
    switch (status?.toString()) {
      case 'completed':
        return AppTheme.emerald;
      case 'pending':
        return AppTheme.gold;
      case 'rejected':
        return AppTheme.coral;
      default:
        return Colors.white54;
    }
  }

  /// Local date (YYYY-MM-DD) of the backend's naive-UTC ISO `created_at` (empty when missing).
  static String datePart(dynamic iso) {
    final local = parseServerDateTime(iso);
    if (local == null) return iso?.toString().split('T').first ?? '';
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd';
  }

  /// /admin/database/health answers status/connection 'unhealthy' (latency -1) when the DB ping fails.
  static bool isDbHealthy(Map<String, dynamic>? health) {
    if (health == null) return false;
    return health['connection'] == 'healthy' || (health['connection'] == null && health['status'] == 'healthy');
  }
}

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
  
  // Cards fleet data (server-side search + paging; the backend caps a page at 100 wallets)
  static const int _cardsPageSize = 100;
  List<dynamic> _cards = [];
  int _cardsTotal = 0;
  bool _isLoadingMoreCards = false;
  String _cardSearchQuery = '';
  // Owned by the State so the visible text survives the refresh spinner rebuilding the tab
  final TextEditingController _cardSearchController = TextEditingController();
  Timer? _cardSearchDebounce;
  int _cardsRequestId = 0;

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
    _cardSearchDebounce?.cancel();
    _cardSearchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _cardsQuery({int offset = 0}) {
    final search = _cardSearchQuery.trim();
    return {
      'limit': _cardsPageSize,
      'offset': offset,
      if (search.isNotEmpty) 'search': search,
    };
  }

  int _readTotal(dynamic data, int fallback) {
    final total = data is Map ? data['total'] : null;
    return total is num ? total.toInt() : fallback;
  }

  Future<void> _loadAllAdminData() async {
    _cardSearchDebounce?.cancel();
    final requestId = ++_cardsRequestId;
    setState(() {
      _isLoading = true;
      _isLoadingMoreCards = false;
      _errorMessage = null;
    });

    try {
      final client = ApiClient();
      
      // Parallel fetch of admin data
      final results = await Future.wait([
        client.get(ApiConfig.adminOverview),
        client.get(ApiConfig.adminCards, queryParameters: _cardsQuery()),
        client.get(ApiConfig.adminTransactions),
        client.get(ApiConfig.adminDbHealth),
        client.get(ApiConfig.adminSecurityAlerts),
      ]);

      if (!mounted) return;
      setState(() {
        _overview = results[0].data;
        if (requestId == _cardsRequestId) {
          _cards = List<dynamic>.from(results[1].data['items'] ?? []);
          _cardsTotal = _readTotal(results[1].data, _cards.length);
        }
        _transactions = results[2].data['items'] ?? [];
        _dbHealth = results[3].data;
        _securityAlerts = results[4].data;
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

  /// Reloads (or appends the next page of) the card fleet using the server-side search,
  /// so cards beyond the first page can still be found and frozen.
  Future<void> _loadCards({bool append = false}) async {
    final requestId = ++_cardsRequestId;
    if (append) setState(() => _isLoadingMoreCards = true);

    try {
      final res = await ApiClient().get(
        ApiConfig.adminCards,
        queryParameters: _cardsQuery(offset: append ? _cards.length : 0),
      );
      if (!mounted || requestId != _cardsRequestId) return;

      final items = List<dynamic>.from(res.data['items'] ?? []);
      setState(() {
        _cards = append ? [..._cards, ...items] : items;
        _cardsTotal = _readTotal(res.data, _cards.length);
        _isLoadingMoreCards = false;
      });
    } catch (e) {
      if (!mounted || requestId != _cardsRequestId) return;
      setState(() => _isLoadingMoreCards = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiErrorHandler.getErrorMessage(e)),
          backgroundColor: AppTheme.coral,
        ),
      );
    }
  }

  void _onCardSearchChanged(String val) {
    setState(() => _cardSearchQuery = val);
    _cardSearchDebounce?.cancel();
    _cardSearchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadCards();
    });
  }

  Future<void> _updateCardStatus(String walletId, String newStatus, String childName) async {
    try {
      await ApiClient().patch(
        '/admin/cards/$walletId/status',
        data: {'card_status': newStatus},
      );

      if (!mounted) return;
      setState(() {
        final index = _cards.indexWhere((c) => c['wallet_id'] == walletId);
        if (index != -1) {
          _cards[index]['card_status'] = newStatus;
        }
      });

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
          // The dashboard can be the root route (restored admin session from splash), so it needs its own exit
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.coral),
            tooltip: 'تسجيل الخروج',
            onPressed: () async {
              await Provider.of<AuthState>(context, listen: false).logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                (route) => false,
              );
            },
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
                    '${AdminDashboardFormat.egp(liquidity['total_egp'])} ج.م',
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
                              Text('${AdminDashboardFormat.egp(liquidity['wallets_balance_egp'])} ج.م', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                              Text('${AdminDashboardFormat.egp(liquidity['savings_balance_egp'])} ج.م', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    // Instant local refinement while the debounced server-side search is in flight
    final q = _cardSearchQuery.trim().toLowerCase();
    final filtered = _cards.where((c) {
      if (q.isEmpty) return true;
      final child = (c['child_name'] ?? '').toString().toLowerCase();
      final fam = (c['family_name'] ?? '').toString().toLowerCase();
      final num = (c['card_number'] ?? '').toString().toLowerCase();
      return child.contains(q) || fam.contains(q) || num.contains(q);
    }).toList();
    final hasMoreCards = _cards.length < _cardsTotal;

    return RefreshIndicator(
      onRefresh: _loadAllAdminData,
      color: AppTheme.gold,
      backgroundColor: const Color(0xFF0A1128),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _cardSearchController,
              style: const TextStyle(color: Colors.white),
              onChanged: _onCardSearchChanged,
              decoration: InputDecoration(
                hintText: 'ابحث باسم الطفل أو العائلة أو رقم الكارت...',
                hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: AppTheme.gold),
                suffixIcon: _cardSearchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white54, size: 20),
                        onPressed: () {
                          _cardSearchController.clear();
                          _onCardSearchChanged('');
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFF131D38),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (_cardsTotal > 0)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'عرض ${_cards.length} من $_cardsTotal كارت',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ),
          Expanded(
            child: filtered.isEmpty && !hasMoreCards
                ? const Center(child: Text('لا توجد كروت مطابقة للبحث', style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length + (hasMoreCards ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= filtered.length) {
                        // Footer: next page of the fleet (the backend returns at most 100 wallets per page)
                        return Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 24),
                          child: Column(
                            children: [
                              if (filtered.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text('لا توجد كروت مطابقة في الصفحات المحملة', style: TextStyle(color: Colors.white54)),
                                ),
                              _isLoadingMoreCards
                                  ? const CircularProgressIndicator(color: AppTheme.gold)
                                  : OutlinedButton.icon(
                                      onPressed: () => _loadCards(append: true),
                                      icon: const Icon(Icons.expand_more, color: AppTheme.gold),
                                      label: const Text('تحميل المزيد', style: TextStyle(color: AppTheme.gold)),
                                      style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.gold)),
                                    ),
                            ],
                          ),
                        );
                      }
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
                                Text('الرصيد: ${AdminDashboardFormat.egp(card['balance'])} ج.م', style: const TextStyle(color: AppTheme.gold, fontWeight: FontWeight.bold)),
                                // null daily_limit = no daily limit (never a 100 EGP default)
                                Text(AdminDashboardFormat.dailyLimit(card['daily_limit']), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (status == 'deactivated')
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: Text('كارت ملغي نهائياً ⛔', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
                                  )
                                else if (isFrozen)
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
                // /admin/transactions items are card purchases: {merchant, category, amount, status, decline_reason, created_at}
                final status = t['status']?.toString();
                final merchant = (t['merchant'] ?? 'معاملة بنكية').toString();
                final category = t['category']?.toString() ?? '';
                final declineReason = t['decline_reason']?.toString();

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
                      // Purchases are always outgoing debits
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.coral.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_upward,
                          color: AppTheme.coral,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.isNotEmpty ? '$merchant • $category' : merchant,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${t['child_name'] ?? ''} (${t['family_name'] ?? ''}) • ${AdminDashboardFormat.datePart(t['created_at'])}',
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            if (status == 'rejected' && declineReason != null && declineReason.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'سبب الرفض: $declineReason',
                                style: const TextStyle(color: AppTheme.coral, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AdminDashboardFormat.purchaseAmount(t['amount']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AdminDashboardFormat.purchaseStatusLabel(status),
                            style: TextStyle(color: AdminDashboardFormat.purchaseStatusColor(status), fontSize: 10),
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
    final dbHealthy = AdminDashboardFormat.isDbHealthy(_dbHealth);
    final latency = _dbHealth?['latency_ms'];
    final latencyText = (latency is num && latency >= 0) ? '$latency ms' : 'غير متاح';

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
                border: Border.all(color: (dbHealthy ? AppTheme.emerald : AppTheme.coral).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('سيرفر قاعدة البيانات (Neon DB) 🗄️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      // Driven by /admin/database/health (status/connection 'unhealthy' when the ping fails)
                      Text(
                        dbHealthy ? 'متصل 🟢' : 'غير متصل 🔴',
                        style: TextStyle(color: dbHealthy ? AppTheme.emerald : AppTheme.coral, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('المزود: ${_dbHealth?['provider'] ?? 'Neon PostgreSQL'}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                  Text('زمن الاستجابة (Latency): $latencyText', style: const TextStyle(color: AppTheme.gold, fontSize: 12, fontWeight: FontWeight.bold)),
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
                      '${a['action']} بواسطة ${a['actor_role']} • ${AdminDashboardFormat.datePart(a['created_at'])}',
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
