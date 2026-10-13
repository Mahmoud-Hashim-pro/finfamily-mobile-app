import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keyToken = 'finfamily_token';
  static const String _keyRole = 'finfamily_role';
  static const String _keyUserId = 'finfamily_user_id';
  static const String _keyFamilyId = 'finfamily_family_id';

  Future<void> saveSession({
    required String token,
    required String role,
    String? userId,
    String? familyId,
  }) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(key: _keyRole, value: role);
    if (userId != null) await _storage.write(key: _keyUserId, value: userId);
    if (familyId != null) await _storage.write(key: _keyFamilyId, value: familyId);
  }

  Future<void> saveRole(String role) async {
    await _storage.write(key: _keyRole, value: role);
  }

  Future<String?> getToken() async => await _storage.read(key: _keyToken);
  Future<String?> getRole() async => await _storage.read(key: _keyRole);
  Future<String?> getUserId() async => await _storage.read(key: _keyUserId);
  Future<String?> getFamilyId() async => await _storage.read(key: _keyFamilyId);

  Future<void> clearSession() async {
    await _storage.deleteAll();
  }
}
