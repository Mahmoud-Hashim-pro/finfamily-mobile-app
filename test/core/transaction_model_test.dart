import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/models/transaction_model.dart';

void main() {
  group('TransactionModel - Validation & Integrity (FF-32)', () {
    test('successfully parses valid transaction json', () {
      final json = {
        'id': 'tx-12345',
        'title': 'School Supplies',
        'category': 'Education',
        'amount': 45.50,
        'direction': 'debit',
        'type': 'card',
        'created_date': '2026-10-21T08:00:00Z',
        'status': 'completed',
        'merchant': 'Bookstore',
        'location': 'Cairo',
      };

      final tx = TransactionModel.fromJson(json);
      expect(tx.id, equals('tx-12345'));
      expect(tx.amount, equals(45.50));
      expect(tx.direction, equals('debit'));
      expect(tx.isIncome, isFalse);
      expect(tx.title, equals('School Supplies'));
      expect(tx.category, equals('Education'));
    });

    test('throws FormatException when id is missing or empty', () {
      final jsonNoId = {
        'title': 'Test',
        'amount': 100.0,
        'direction': 'credit',
      };
      expect(() => TransactionModel.fromJson(jsonNoId), throwsA(isA<FormatException>()));

      final jsonEmptyId = {
        'id': '',
        'amount': 100.0,
        'direction': 'credit',
      };
      expect(() => TransactionModel.fromJson(jsonEmptyId), throwsA(isA<FormatException>()));
    });

    test('throws FormatException when amount is missing or non-numeric', () {
      final jsonNoAmount = {
        'id': 'tx-001',
        'direction': 'credit',
      };
      expect(() => TransactionModel.fromJson(jsonNoAmount), throwsA(isA<FormatException>()));

      final jsonStringAmount = {
        'id': 'tx-002',
        'amount': '100',
        'direction': 'credit',
      };
      expect(() => TransactionModel.fromJson(jsonStringAmount), throwsA(isA<FormatException>()));
    });

    test('throws FormatException when direction is missing or invalid', () {
      final jsonNoDirection = {
        'id': 'tx-003',
        'amount': 50.0,
      };
      expect(() => TransactionModel.fromJson(jsonNoDirection), throwsA(isA<FormatException>()));

      final jsonBadDirection = {
        'id': 'tx-004',
        'amount': 50.0,
        'direction': 'invalid_dir',
      };
      expect(() => TransactionModel.fromJson(jsonBadDirection), throwsA(isA<FormatException>()));
    });
  });
}
