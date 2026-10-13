import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
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
  String? _pendingParentEmail;
  String? _pendingParentPassword;

  // Liveness / readiness synchronization for splash screen and route guards
  Completer<void> _authInitCompleter = Completer<void>();
  bool _isInitialized = false;

  AuthStatus get status => _status;
  String? get role => _role;
  Map<String, dynamic>? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get pendingParentEmail => _pendingParentEmail;
  String? get tempLoginToken => _tempLoginToken;
  bool get isParent => _role == 'parent';
  bool get isChild => _role == 'child';

  // Synchronization helpers
  Future<void> get authInitialized => _authInitCompleter.future;
  bool get isInitialized => _isInitialized;

  /// Super-admin capability is derived strictly from server-authenticated role/claims.
  /// Hardcoded email allowlists are eliminated to prevent phishing/targeting and authorization bypass.
  bool get isSuperAdmin {
    if (_user == null && _role == null) return false;
    return _user?['is_admin'] == true ||
        _role == 'admin' ||
        _user?['role'] == 'admin';
  }

  AuthState() {
    _api.onUnauthorized = () {
      _status = AuthStatus.unauthenticated;
      _user = null;
      _role = null;
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _pendingParentPassword = null;
      notifyListeners();
    };
    checkAuth();
  }

  /// Verifies token and restores session.
  /// Server role is authoritative and overwrites locally cached role.
  /// Transient network errors do NOT clear the session.
  Future<void> checkAuth() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      String? token;
      String? savedRole;

      // Safely access secure storage; handle Android Keystore decryption failures gracefully
      try {
        token = await _storage.getToken();
        savedRole = await _storage.getRole();
      } catch (storageError) {
        // Storage corrupted or restore failure: safely clear corrupted keys
        try {
          await _storage.clearSession();
        } catch (_) {}
        _status = AuthStatus.unauthenticated;
        _markInitialized();
        notifyListeners();
        return;
      }

      if (token == null || token.isEmpty) {
        _status = AuthStatus.unauthenticated;
        _markInitialized();
        notifyListeners();
        return;
      }

      // Verify token with backend
      try {
        final response = await _api.get(ApiConfig.currentUser);
        if (response.data != null && response.data is Map) {
          _user = Map<String, dynamic>.from(response.data);

          // Server role is authoritative over locally cached role
          final serverRole = _user?['role'] as String?;
          if (serverRole != null && serverRole.isNotEmpty) {
            _role = serverRole;
            await _storage.saveRole(serverRole);
          } else if (savedRole != null && savedRole.isNotEmpty) {
            _role = savedRole;
          }

          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.unauthenticated;
        }
      } on DioException catch (dioErr) {
        final statusCode = dioErr.response?.statusCode;
        // Only clear session if token is explicitly rejected (401 Unauthorized / 403 Forbidden with invalid token)
        if (statusCode == 401 || statusCode == 403) {
          try {
            await _storage.clearSession();
          } catch (_) {}
          _user = null;
          _role = null;
          _status = AuthStatus.unauthenticated;
        } else {
          // Keep authenticated session on network failure, timeout, or server 5xx error
          if (savedRole != null && savedRole.isNotEmpty) {
            _role = savedRole;
            _status = AuthStatus.authenticated;
          } else {
            _status = AuthStatus.authenticated;
          }
        }
      } catch (generalErr) {
        // Non-auth exception: preserve session if token exists
        if (savedRole != null && savedRole.isNotEmpty) {
          _role = savedRole;
          _status = AuthStatus.authenticated;
        } else {
          _status = AuthStatus.authenticated;
        }
      }
    } finally {
      _markInitialized();
      notifyListeners();
    }
  }

  void _markInitialized() {
    _isInitialized = true;
    if (!_authInitCompleter.isCompleted) {
      _authInitCompleter.complete();
    }
  }

  /// Refreshes user profile and gamification stats dynamically from /auth/me without requiring relogin.
  Future<void> refreshCurrentUser() async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) return;

      final response = await _api.get(ApiConfig.currentUser);
      if (response.data != null && response.data is Map) {
        _user = Map<String, dynamic>.from(response.data);
        final serverRole = _user?['role'] as String?;
        if (serverRole != null && serverRole.isNotEmpty) {
          _role = serverRole;
          await _storage.saveRole(serverRole);
        }
        notifyListeners();
      }
    } catch (_) {
      // Keep existing state on transient refresh failure
    }
  }

  /// Dynamically updates child gamification and wallet stats in memory and notifies listeners.
  void updateChildStats({int? xp, int? level, int? streak, double? balance}) {
    if (_user != null) {
      final updated = Map<String, dynamic>.from(_user!);
      if (xp != null) updated['xp'] = xp;
      if (level != null) updated['level'] = level;
      if (streak != null) updated['streak'] = streak;
      if (balance != null) updated['balance'] = balance;
      _user = updated;
      notifyListeners();
    }
  }

  // Parent Login
  Future<bool> loginParent(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _pendingParentEmail = email.trim();
    _pendingParentPassword = password;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConfig.parentLogin,
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );

      final data = response.data;
      if (data['mfa_required'] == true) {
        _tempLoginToken = data['temp_token'];
        _status = AuthStatus.requiresMfa;
        notifyListeners();
        return false;
      }

      final token = data['access_token'];
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _pendingParentPassword = null;

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

  // Parent Recovery Code Login
  Future<bool> loginParentWithRecovery(String recoveryCode, {String? email, String? password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    final targetEmail = email?.trim().toLowerCase() ?? _pendingParentEmail;
    final targetPassword = password ?? _pendingParentPassword;

    if (targetEmail == null || targetPassword == null) {
      _errorMessage = 'بيانات تسجيل الدخول غير متوفرة، يرجى كتابة البريد وكلمة المرور مجدداً';
      _status = AuthStatus.requiresMfa;
      notifyListeners();
      return false;
    }

    try {
      final response = await _api.post(
        ApiConfig.parentLogin,
        data: {
          'email': targetEmail,
          'password': targetPassword,
          'recovery_code': recoveryCode.trim().toUpperCase(),
        },
      );

      final token = response.data['access_token'];
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _pendingParentPassword = null;

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
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _pendingParentPassword = null;

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
          'child_id': childId.trim(),
          'pin': pin.trim(),
        },
      );

      final token = response.data['access_token'];
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _pendingParentPassword = null;

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
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _pendingParentPassword = null;
      _role = 'admin';

      await _storage.saveSession(token: token, role: 'admin');
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
          'email': email.trim().toLowerCase(),
          'password': password,
          'family_name': familyName.trim(),
        },
      );

      final token = response.data['access_token'];
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _pendingParentPassword = null;

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
    try {
      await _storage.clearSession();
    } catch (_) {}
    _user = null;
    _role = null;
    _tempLoginToken = null;
    _pendingParentEmail = null;
    _pendingParentPassword = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
