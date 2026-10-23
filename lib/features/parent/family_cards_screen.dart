import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/card_model.dart';
import '../../core/api_client.dart';
import '../../config/api_config.dart';
import '../../core/error_handler.dart';
import '../../widgets/meeza_card_widget.dart';
import 'family_members_screen.dart';

class FamilyCardsScreen extends StatefulWidget {
  const FamilyCardsScreen({super.key});

  @override
  State<FamilyCardsScreen> createState() => _FamilyCardsScreenState();
}

class _FamilyCardsScreenState extends State<FamilyCardsScreen> {
  List<CardModel> _cards = [];
  bool _isLoading = true;
  String? _errorMessage;
  // userIds with a card replacement in flight
  final Set<String> _replacing = {};

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiClient().get(ApiConfig.familyOverview);
      final rawChildren = (res.data['children'] as List<dynamic>?) ?? [];

      final List<CardModel> loaded = [];
      for (var c in rawChildren) {
        loaded.add(
          CardModel(
            id: c['id']?.toString() ?? '',
            userId: c['id']?.toString() ?? '',
            cardNumber: c['card_number']?.toString() ?? '',
            cardholderName: c['full_name']?.toString() ?? 'بطل مالي',
            status: c['card_status']?.toString() ?? 'active',
            expiryDate: c['card_expiry']?.toString() ??
                c['expiry_date']?.toString(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _cards = loaded;
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

  /// Writes an updated card back by its stable userId — never by a list index captured before an await,
  /// because a concurrent refresh can reorder or shrink [_cards].
  void _replaceCardInList(CardModel updated) {
    final i = _cards.indexWhere((c) => c.userId == updated.userId);
    if (i == -1) return; // card vanished during a concurrent refresh; nothing to update
    _cards[i] = updated;
  }

  Future<void> _toggleFreeze(int index) async {
    final current = _cards[index];
    if (current.isDeactivated) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الكارت ملغي نهائياً، استخدم زر "استخراج كارت جديد" لإصدار كارت بديل.'),
          backgroundColor: AppTheme.coral,
        ),
      );
      return;
    }
    final newStatus = current.isFrozen ? 'active' : 'frozen';

    try {
      await ApiClient().patch(
        '/wallet/child/${current.userId}/card-status',
        data: {'card_status': newStatus},
      );

      if (!mounted) return;
      setState(() {
        _replaceCardInList(CardModel(
          id: current.id,
          userId: current.userId,
          cardNumber: current.cardNumber,
          cardholderName: current.cardholderName,
          status: newStatus,
          expiryDate: current.expiryDate,
        ));
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'frozen'
                ? 'تم تجميد كارت ${current.cardholderName} بنجاح 🔒'
                : 'تم تنشيط كارت ${current.cardholderName} بنجاح 🔓',
          ),
          backgroundColor:
              newStatus == 'frozen' ? AppTheme.coral : AppTheme.emerald,
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

  /// A deactivated card can only be replaced: POST /wallet/child/{id}/card/replace issues a new card number
  /// and sets the card back to active.
  Future<void> _replaceCard(CardModel current) async {
    if (_replacing.contains(current.userId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('استخراج كارت جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text(
          'سيتم إصدار كارت ميزة جديد برقم جديد لـ ${current.cardholderName} وتفعيله فوراً. هل تريد المتابعة؟',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navy, foregroundColor: Colors.white),
            child: const Text('استخراج الكارت'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _replacing.add(current.userId));
    try {
      final res = await ApiClient().post(ApiConfig.childCardReplace(current.userId));
      final data = res.data is Map ? res.data as Map : const {};

      if (!mounted) return;
      setState(() {
        _replaceCardInList(CardModel(
          id: current.id,
          userId: current.userId,
          cardNumber: data['card_number']?.toString() ?? current.cardNumber,
          cardholderName: current.cardholderName,
          status: data['card_status']?.toString() ?? 'active',
          expiryDate: current.expiryDate,
        ));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم استخراج كارت جديد لـ ${current.cardholderName} وتفعيله بنجاح 💳'),
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
      if (mounted) {
        setState(() => _replacing.remove(current.userId));
      } else {
        _replacing.remove(current.userId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('كروت ميزة العائلية (Meeza Cards)'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadCards,
          color: AppTheme.navy,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppTheme.coral, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppTheme.coral),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadCards,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _cards.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('💳',
                                    style: TextStyle(fontSize: 48)),
                                const SizedBox(height: 12),
                                const Text(
                                  'لا توجد كروت ميزة مفعلة حتى الآن',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.navy,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'قم بإضافة طفل في شاشة أفراد العائلة ليتم توليد كارت ميزة افتراضي له فوراً',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textMuted),
                                ),
                                const SizedBox(height: 20),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.navy,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 12),
                                  ),
                                  onPressed: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const FamilyMembersScreen(),
                                      ),
                                    );
                                    _loadCards();
                                  },
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('إضافة بطل مالي'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          itemCount: _cards.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 32),
                          itemBuilder: (context, index) {
                            final card = _cards[index];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      card.cardholderName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.navy,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: card.isDeactivated
                                            ? Colors.grey.withOpacity(0.18)
                                            : card.isFrozen
                                                ? AppTheme.coral.withOpacity(0.12)
                                                : AppTheme.emerald
                                                    .withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        card.isDeactivated
                                            ? 'ملغي نهائياً ⛔'
                                            : card.isFrozen
                                                ? 'مجمد 🔒'
                                                : 'نشط ومفعل ✅',
                                        style: TextStyle(
                                          color: card.isDeactivated
                                              ? Colors.grey.shade700
                                              : card.isFrozen
                                                  ? AppTheme.coral
                                                  : AppTheme.emeraldDark,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                MeezaCardWidget(
                                  card: card,
                                  showControls: true,
                                  onFreezeToggle: card.isDeactivated
                                      ? null
                                      : () => _toggleFreeze(index),
                                ),
                                if (card.isDeactivated) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _replacing.contains(card.userId)
                                          ? null
                                          : () => _replaceCard(card),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.navy,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      icon: _replacing.contains(card.userId)
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.autorenew, size: 18),
                                      label: const Text('استخراج كارت جديد'),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
        ),
      ),
    );
  }
}
