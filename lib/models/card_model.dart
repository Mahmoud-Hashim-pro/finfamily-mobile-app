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
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      cardNumber: json['card_number']?.toString() ?? '',
      cardholderName: json['cardholder_name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'unissued',
      expiryDate: json['expiry_date']?.toString(),
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
