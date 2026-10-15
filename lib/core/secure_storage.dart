import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
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
    // 1. Write to FlutterSecureStorage
    try {
      await _storage.write(key: _keyToken, value: token);
      await _storage.write(key: _keyRole, value: role);
      if (userId != null && userId.isNotEmpty) {
        await _storage.write(key: _keyUserId, value: userId);
      } else {
        await _storage.delete(key: _keyUserId);
      }
      if (familyId != null && familyId.isNotEmpty) {
        await _storage.write(key: _keyFamilyId, value: familyId);
      } else {
        await _storage.delete(key: _keyFamilyId);
      }
    } catch (_) {
      // In case FlutterSecureStorage throws, proceed to SharedPreferences backup
    }

    // 2. Write to SharedPreferences as reliable fallback/backup
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyToken, token);
      await prefs.setString(_keyRole, role);
      if (userId != null && userId.isNotEmpty) {
        await prefs.setString(_keyUserId, userId);
      } else {
        await prefs.remove(_keyUserId);
      }
      if (familyId != null && familyId.isNotEmpty) {
        await prefs.setString(_keyFamilyId, familyId);
      } else {
        await prefs.remove(_keyFamilyId);
      }
    } catch (_) {}
  }

  Future<void> saveRole(String role) async {
    try {
      await _storage.write(key: _keyRole, value: role);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyRole, role);
    } catch (_) {}
  }

  Future<String?> _readValue(String key) async {
    // Attempt 1: Read from FlutterSecureStorage
    try {
      final val = await _storage.read(key: key);
      if (val != null && val.isNotEmpty) {
        return val;
      }
    } catch (_) {
      // Fallback on exception (e.g. Android Keystore reset / decryption error)
    }

    // Attempt 2: Automatic fallback to SharedPreferences if null or on exception
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getString(key);
      if (val != null && val.isNotEmpty) {
        // Self-heal: sync back to secure storage
        try {
          await _storage.write(key: key, value: val);
        } catch (_) {}
        return val;
      }
    } catch (_) {}

    return null;
  }

  Future<String?> getToken() => _readValue(_keyToken);
  Future<String?> getRole() => _readValue(_keyRole);
  Future<String?> getUserId() => _readValue(_keyUserId);
  Future<String?> getFamilyId() => _readValue(_keyFamilyId);

  Future<void> clearSession() async {
    // Clear FlutterSecureStorage
    try {
      await _storage.deleteAll();
    } catch (_) {
      try {
        await _storage.delete(key: _keyToken);
        await _storage.delete(key: _keyRole);
        await _storage.delete(key: _keyUserId);
        await _storage.delete(key: _keyFamilyId);
      } catch (_) {}
    }

    // Clear SharedPreferences session keys
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyRole);
      await prefs.remove(_keyUserId);
      await prefs.remove(_keyFamilyId);
    } catch (_) {}
  }
}
