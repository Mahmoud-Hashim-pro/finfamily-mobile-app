import 'package:flutter/material.dart';
import 'api_client.dart';
import 'secure_storage.dart';
import 'error_handler.dart';
import '../config/api_config.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, requiresMfa }

class AuthState extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  final SecureStorageService _storage = SecureStorageService();

  AuthStatus _status = AuthStatus.initial;
  String? _role;
  Map<String, dynamic>? _user;
  String? _errorMessage;
  String? _tempLoginToken;

  AuthStatus get status => _status;
  String? get role => _role;
  Map<String, dynamic>? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isParent => _role == 'parent';
  bool get isChild => _role == 'child';

  static const List<String> superAdminEmails = [
    'modyhashim2006@gmail.com',
    'pro.mahmoud.h@gmail.com',
    'bassantmohamedelramlaw@gmail.com',
    'abdallah.ahmed@finfamily.com',
    'omar.osama.sw.dev@gmail.com',
    'ashayman111@gmail.com',
    'ramezrizkw@gmail.com',
    'zyad.ahmed.softwareeng@gmail.com',
  ];

  bool get isSuperAdmin {
    final email = (_user?['email'] ?? '').toString().toLowerCase().trim();
    return superAdminEmails.contains(email);
  }

  AuthState() {
    _api.onUnauthorized = () {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _role = null;
      notifyListeners();
    };
    checkAuth();
  }

  Future<void> checkAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final token = await _storage.getToken();
      final savedRole = await _storage.getRole();

      if (token == null || token.isEmpty) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      // Verify token with backend
      final response = await _api.get(ApiConfig.currentUser);
      _user = response.data;
      _role = savedRole ?? _user?['role'];
      _status = AuthStatus.authenticated;
    } catch (_) {
      await _storage.clearSession();
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  // Parent Login
  Future<bool> loginParent(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConfig.parentLogin,
        data: {'email': email.trim(), 'password': password},
      );

      final data = response.data;
      if (data['mfa_required'] == true) {
        _tempLoginToken = data['temp_token'];
        _status = AuthStatus.requiresMfa;
        notifyListeners();
        return false;
      }

      final token = data['access_token'];
      await _storage.saveSession(token: token, role: 'parent');
      await checkAuth();
      return true;
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Super Admin Direct Login
  Future<bool> loginAdmin(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConfig.adminLogin,
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );

      final token = response.data['access_token'];
      await _storage.saveSession(token: token, role: 'parent');
      await checkAuth();
      return true;
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Parent MFA Verify
  Future<bool> verifyMfa(String code) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConfig.mfaVerify,
        data: {
          'temp_token': _tempLoginToken,
          'code': code.trim(),
        },
      );

      final token = response.data['access_token'];
      await _storage.saveSession(token: token, role: 'parent');
      await checkAuth();
      return true;
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      _status = AuthStatus.requiresMfa;
      notifyListeners();
      return false;
    }
  }

  // Child Login (Family Code + PIN)
  Future<bool> loginChild(String familyCode, String childId, String pin) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConfig.childLogin,
        data: {
          'family_code': familyCode.trim().toUpperCase(),
          'child_id': childId,
          'pin': pin.trim(),
        },
      );

      final token = response.data['access_token'];
      await _storage.saveSession(token: token, role: 'child');
      await checkAuth();
      return true;
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Parent Register
  Future<bool> registerParent({
    required String fullName,
    required String email,
    required String password,
    required String familyName,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConfig.parentRegister,
        data: {
          'full_name': fullName.trim(),
          'email': email.trim(),
          'password': password,
          'family_name': familyName.trim(),
        },
      );

      final token = response.data['access_token'];
      await _storage.saveSession(token: token, role: 'parent');
      await checkAuth();
      return true;
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _storage.clearSession();
    _user = null;
    _role = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
