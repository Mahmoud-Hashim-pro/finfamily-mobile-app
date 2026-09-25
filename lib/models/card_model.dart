class CardModel {
  final String id;
  final String userId;
  final String cardNumber;
  final String cardholderName;
  final String status; // active, frozen, deactivated
  final String? expiryDate;

  CardModel({
    required this.id,
    required this.userId,
    required this.cardNumber,
    required this.cardholderName,
    required this.status,
    this.expiryDate,
  });

  bool get isActive => status == 'active';
  bool get isFrozen => status == 'frozen';
  bool get isDeactivated => status == 'deactivated';

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      cardNumber: json['card_number'] ?? '5061 •••• •••• 1234',
      cardholderName: json['cardholder_name'] ?? 'FinFamily Member',
      status: json['status'] ?? 'active',
      expiryDate: json['expiry_date'] ?? '12/28',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'card_number': cardNumber,
      'cardholder_name': cardholderName,
      'status': status,
      'expiry_date': expiryDate,
    };
  }
}
