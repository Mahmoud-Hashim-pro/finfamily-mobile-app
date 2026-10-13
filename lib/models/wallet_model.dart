class WalletModel {
  final String id;
  final String userId;
  final double balance;
  final double savingsBalance;
  final double? dailyLimit;
  final double? weeklyLimit;
  final double? monthlyLimit;
  final double spentToday;
  final double spentThisWeek;
  final double spentThisMonth;
  final List<String> blockedCategories;

  WalletModel({
    required this.id,
    required this.userId,
    this.balance = 0.0,
    this.savingsBalance = 0.0,
    this.dailyLimit,
    this.weeklyLimit,
    this.monthlyLimit,
    this.spentToday = 0.0,
    this.spentThisWeek = 0.0,
    this.spentThisMonth = 0.0,
    this.blockedCategories = const [],
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      savingsBalance: (json['savings_balance'] as num?)?.toDouble() ?? 0.0,
      dailyLimit: (json['daily_limit'] as num?)?.toDouble(),
      weeklyLimit: (json['weekly_limit'] as num?)?.toDouble(),
      monthlyLimit: (json['monthly_limit'] as num?)?.toDouble(),
      spentToday: (json['spent_today'] as num?)?.toDouble() ?? 0.0,
      spentThisWeek: (json['spent_this_week'] as num?)?.toDouble() ?? 0.0,
      spentThisMonth: (json['spent_this_month'] as num?)?.toDouble() ?? 0.0,
      blockedCategories: (json['blocked_categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
