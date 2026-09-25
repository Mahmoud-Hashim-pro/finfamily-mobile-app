class TransactionModel {
  final String id;
  final String title;
  final String category;
  final double amount;
  final String direction; // credit, debit
  final String type; // allowance, card_purchase, mission_reward, redemption, etc.
  final DateTime date;
  final String status;
  final String? merchant;
  final String? location;

  TransactionModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.direction,
    required this.type,
    required this.date,
    this.status = 'completed',
    this.merchant,
    this.location,
  });

  bool get isIncome => direction == 'credit';

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      id: json['id'] ?? '',
      title: json['title'] ?? json['merchant'] ?? 'Transaction',
      category: json['category'] ?? 'General',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      direction: json['direction'] ?? (json['amount'] != null && json['amount'] > 0 ? 'credit' : 'debit'),
      type: json['type'] ?? 'card',
      date: json['date'] != null ? DateTime.tryParse(json['date']) ?? DateTime.now() : DateTime.now(),
      status: json['status'] ?? 'completed',
      merchant: json['merchant'],
      location: json['location'],
    );
  }
}
