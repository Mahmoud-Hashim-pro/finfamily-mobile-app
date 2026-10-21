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
    // FF-32: Disallow silent defaults for missing id, amount, and direction
    final rawId = json['id']?.toString().trim();
    if (rawId == null || rawId.isEmpty) {
      throw const FormatException('TransactionModel: missing or empty required field "id"');
    }

    final rawAmount = json['amount'];
    if (rawAmount == null || rawAmount is! num) {
      throw const FormatException('TransactionModel: missing or non-numeric required field "amount"');
    }
    final amount = rawAmount.toDouble();

    final rawDirection = json['direction']?.toString().trim().toLowerCase();
    if (rawDirection == null || (rawDirection != 'credit' && rawDirection != 'debit')) {
      throw const FormatException('TransactionModel: missing or invalid required field "direction" (must be "credit" or "debit")');
    }

    final rawDate = json['created_date'] ?? json['date'];
    final parsedDate = rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;

    return TransactionModel(
      id: rawId,
      title: json['title']?.toString() ?? json['description']?.toString() ?? json['merchant']?.toString() ?? 'Transaction',
      category: json['category']?.toString() ?? 'General',
      amount: amount,
      direction: rawDirection,
      type: json['type']?.toString() ?? 'card',
      date: parsedDate ?? DateTime.now(),
      status: json['status']?.toString() ?? 'completed',
      merchant: json['merchant']?.toString(),
      location: json['location']?.toString(),
    );
  }
}
