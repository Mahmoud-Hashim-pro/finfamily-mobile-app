class UserModel {
  final String id;
  final String familyId;
  final String role;
  final String fullName;
  final String? email;
  final int? age;
  final String? avatar;
  final int level;
  final int xp;
  final int coins;
  final int streak;
  final bool? mfaEnabled;

  UserModel({
    required this.id,
    required this.familyId,
    required this.role,
    required this.fullName,
    this.email,
    this.age,
    this.avatar,
    this.level = 1,
    this.xp = 0,
    this.coins = 0,
    this.streak = 0,
    this.mfaEnabled,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      familyId: json['family_id'] ?? '',
      role: json['role'] ?? 'parent',
      fullName: json['full_name'] ?? '',
      email: json['email'],
      age: json['age'],
      avatar: json['avatar'],
      level: json['level'] ?? 1,
      xp: json['xp'] ?? 0,
      coins: json['coins'] ?? 0,
      streak: json['streak'] ?? 0,
      mfaEnabled: json['mfa_enabled'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'role': role,
      'full_name': fullName,
      'email': email,
      'age': age,
      'avatar': avatar,
      'level': level,
      'xp': xp,
      'coins': coins,
      'streak': streak,
      'mfa_enabled': mfaEnabled,
    };
  }
}
