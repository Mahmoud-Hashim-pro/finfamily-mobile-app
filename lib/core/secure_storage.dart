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
  static const String _keyHasSession = 'finfamily_has_session';

  Future<void> saveSession({
    required String token,
    required String role,
    String? userId,
    String? familyId,
  }) async {
    // 1. Bearer Token MUST ONLY be stored in platform-backed encrypted secure storage
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
      // In case FlutterSecureStorage throws on initial write
    }

    // 2. SharedPreferences ONLY stores non-sensitive UI display metadata (NEVER the bearer token)
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken); // Ensure bearer token is NEVER stored in plaintext preferences
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
      await prefs.setBool(_keyHasSession, true);
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

  /// Bearer token is strictly read from platform-backed secure storage.
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _keyToken);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readMetadata(String key) async {
    try {
      final val = await _storage.read(key: key);
      if (val != null && val.isNotEmpty) {
        return val;
      }
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  Future<String?> getRole() => _readMetadata(_keyRole);
  Future<String?> getUserId() => _readMetadata(_keyUserId);
  Future<String?> getFamilyId() => _readMetadata(_keyFamilyId);
  Future<bool> hasCachedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyHasSession) ?? false;
    } catch (_) {
      return false;
    }
  }

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
      await prefs.remove(_keyHasSession);
    } catch (_) {}
  }
}
