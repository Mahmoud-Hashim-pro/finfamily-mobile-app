
import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/models/transaction_model.dart';

void main() {
  group('TransactionModel edge cases', () {
    Map<String, dynamic> makeTransaction({
      Object amount = 100,
      String direction = 'debit',
      String date = '2026-10-21T08:00:00Z',
    }) {
      return {
        'id': 'test-transaction-001',
        'title': 'Test transaction',
        'category': 'Test',
        'amount': amount,
        'direction': direction,
        'created_date': date,
      };
    }

    test('accepts a valid transaction', () {
      final transaction = TransactionModel.fromJson(
        makeTransaction(),
      );

      expect(transaction.id, 'test-transaction-001');
      expect(transaction.amount, 100.0);
      expect(transaction.direction, 'debit');
    });

    test('rejects a negative transaction amount', () {
      expect(
        () => TransactionModel.fromJson(
          makeTransaction(amount: -100),
        ),
        throwsFormatException,
      );
    });

    test('rejects NaN transaction amount', () {
      expect(
        () => TransactionModel.fromJson(
          makeTransaction(amount: double.nan),
        ),
        throwsFormatException,
      );
    });

    test('rejects infinite transaction amount', () {
      expect(
        () => TransactionModel.fromJson(
          makeTransaction(amount: double.infinity),
        ),
        throwsFormatException,
      );
    });

    test('rejects an invalid transaction direction', () {
      expect(
        () => TransactionModel.fromJson(
          makeTransaction(direction: 'unknown'),
        ),
        throwsFormatException,
      );
    });
  });
}
