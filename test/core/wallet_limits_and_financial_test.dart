import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/models/wallet_model.dart';

void main() {
  group('WalletModel - Financial Deserialization & Limits Integrity', () {
    test('parses json with full limits and floating point numbers accurately', () {
      final json = {
        'id': 'w_123',
        'user_id': 'u_456',
        'balance': 1500.50,
        'savings_balance': 300.25,
        'daily_limit': 100.0,
        'weekly_limit': 500.0,
        'monthly_limit': 2000.0,
        'spent_today': 45.50,
        'spent_this_week': 210.0,
        'spent_this_month': 850.0,
        'blocked_categories': ['gaming', 'gambling'],
      };

      final wallet = WalletModel.fromJson(json);

      expect(wallet.id, equals('w_123'));
      expect(wallet.userId, equals('u_456'));
      expect(wallet.balance, equals(1500.50));
      expect(wallet.savingsBalance, equals(300.25));
      expect(wallet.dailyLimit, equals(100.0));
      expect(wallet.weeklyLimit, equals(500.0));
      expect(wallet.monthlyLimit, equals(2000.0));
      expect(wallet.spentToday, equals(45.50));
      expect(wallet.spentThisWeek, equals(210.0));
      expect(wallet.spentThisMonth, equals(850.0));
      expect(wallet.blockedCategories, containsAll(['gaming', 'gambling']));
    });

    test('handles missing or null limits gracefully with safe defaults', () {
      final json = {
        'id': 'w_789',
        'user_id': 'u_101',
        'balance': 250,
      };

      final wallet = WalletModel.fromJson(json);

      expect(wallet.id, equals('w_789'));
      expect(wallet.balance, equals(250.0));
      expect(wallet.savingsBalance, equals(0.0));
      expect(wallet.dailyLimit, isNull);
      expect(wallet.weeklyLimit, isNull);
      expect(wallet.monthlyLimit, isNull);
      expect(wallet.spentToday, equals(0.0));
      expect(wallet.blockedCategories, isEmpty);
    });

    test('computes remaining daily budget and limit breach correctly', () {
      final wallet = WalletModel(
        id: 'w_test',
        userId: 'u_test',
        balance: 500.0,
        dailyLimit: 100.0,
        spentToday: 75.0,
      );

      final remainingDaily = wallet.dailyLimit! - wallet.spentToday;
      final utilization = wallet.spentToday / wallet.dailyLimit!;

      expect(remainingDaily, equals(25.0));
      expect(utilization, equals(0.75));
      expect(remainingDaily > 0, isTrue);

      final overspentWallet = WalletModel(
        id: 'w_test_over',
        userId: 'u_test',
        balance: 500.0,
        dailyLimit: 50.0,
        spentToday: 60.0,
      );

      final isLimitExceeded = overspentWallet.spentToday > overspentWallet.dailyLimit!;
      expect(isLimitExceeded, isTrue);
    });
  });
}
