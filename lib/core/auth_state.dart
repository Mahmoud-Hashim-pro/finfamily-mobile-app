import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_client.dart';
import 'secure_storage.dart';
import 'error_handler.dart';
import '../config/api_config.dart';
import '../widgets/custom_text_field.dart' show normalizeArabicDigits;

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
  String? _pendingGoogleEmail;
  String? _pendingGoogleName;
  bool _isGoogleAccountUnregistered = false;

  // Mandatory admin MFA (C2): the admin login only returns a short-lived challenge / enrollment
  // token. It is kept in memory (_tempLoginToken) and is NEVER persisted as a session.
  bool _adminMfaPending = false;
  bool _adminMfaEnrollmentRequired = false;
  String? _adminMfaSecret;
  String? _adminMfaQrCode;
  String? _adminMfaProvisioningUri;
  List<String>? _adminRecoveryCodes;

  // Liveness / readiness synchronization for splash screen and route guards
  final Completer<void> _authInitCompleter = Completer<void>();
  bool _isInitialized = false;
  bool _isServerVerified = false;

  /// Incremented once whenever a live session (already handed to the UI) is invalidated by the
  /// backend (401). The app root listens to it and returns to the role-select screen (C4).
  final ValueNotifier<int> _sessionExpired = ValueNotifier<int>(0);
  int _activeAuthChecks = 0;
  // Bumped on every session change (checkAuth / logout / 401) so late async results can be dropped
  int _authGeneration = 0;
  bool _disposed = false;
  late final void Function() _onUnauthorizedHandler;

  /// Back-off used to re-verify a session restored while /auth/me was slow or unreachable.
  @visibleForTesting
  static List<Duration> profileRecoveryDelays = const [
    Duration(seconds: 2),
    Duration(seconds: 5),
    Duration(seconds: 10),
  ];

  AuthStatus get status => _status;
  String? get role => _role;
  Map<String, dynamic>? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get pendingParentEmail => _pendingParentEmail;
  String? get pendingGoogleEmail => _pendingGoogleEmail;
  String? get pendingGoogleName => _pendingGoogleName;
  bool get isGoogleAccountUnregistered => _isGoogleAccountUnregistered;
  String? get tempLoginToken => _tempLoginToken;
  bool get isParent => _role == 'parent';
  bool get isChild => _role == 'child';
  bool get isServerVerified => _isServerVerified;
  bool get isVerifiedParent => _isServerVerified && _role == 'parent';
  bool get isVerifiedChild => _isServerVerified && _role == 'child';
  /// Distinguishes an offline or unverified restored session from a server-confirmed active session.
  bool get isRestoredOfflineSession => _status == AuthStatus.authenticated && !_isServerVerified;

  /// False only for accounts the backend reports as password-less (Google-only parents, C13).
  bool get hasPassword => _user?['has_password'] != false;

  // Admin MFA step (C2)
  bool get adminMfaPending => _adminMfaPending && _tempLoginToken != null;
  bool get adminMfaEnrollmentRequired => _adminMfaEnrollmentRequired;
  String? get adminMfaSecret => _adminMfaSecret;
  /// `data:image/png;base64,...` URI of the enrollment QR code, or null.
  String? get adminMfaQrCode => _adminMfaQrCode;
  String? get adminMfaProvisioningUri => _adminMfaProvisioningUri;
  /// Recovery codes returned once when the admin completes MFA enrollment.
  List<String>? get adminRecoveryCodes => _adminRecoveryCodes;

  /// Fires when an active session is invalidated by the server (see [_sessionExpired]).
  ValueListenable<int> get sessionExpired => _sessionExpired;

  // Synchronization helpers
  Future<void> get authInitialized => _authInitCompleter.future;
  bool get isInitialized => _isInitialized;

  /// Super-admin capability is derived strictly from server-authenticated role/claims AND verified with backend.
  /// Locally cached or unverified offline roles NEVER grant super-admin access or local admin UI.
  bool get isSuperAdmin {
    if (!_isServerVerified || _user == null) return false;
    return _user?['is_admin'] == true ||
        _user?['role'] == 'admin' ||
        _role == 'admin';
  }

  AuthState() {
    _onUnauthorizedHandler = () {
      // Only a session that was already live in the UI counts as "expired". Concurrent 401s,
      // follow-up "Not authenticated" 401s, and checkAuth's own 401 (splash / post-login) don't.
      final wasActive = _isInitialized &&
          _activeAuthChecks == 0 &&
          _status == AuthStatus.authenticated;
      _authGeneration++;
      _status = AuthStatus.unauthenticated;
      _user = null;
      _role = null;
      _isServerVerified = false;
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _pendingGoogleEmail = null;
      _pendingGoogleName = null;
      _isGoogleAccountUnregistered = false;
      _clearAdminMfaState(clearRecoveryCodes: true);
      notifyListeners();
      if (wasActive) {
        _sessionExpired.value++;
      }
    };
    _api.onUnauthorized = _onUnauthorizedHandler;
    checkAuth();
  }

  @override
  void dispose() {
    _disposed = true;
    _authGeneration++;
    if (identical(_api.onUnauthorized, _onUnauthorizedHandler)) {
      _api.onUnauthorized = null;
    }
    _sessionExpired.dispose();
    super.dispose();
  }

  /// Verifies token and restores session.
  /// Server role is authoritative and overwrites locally cached role.
  /// Transient network errors do NOT clear the session.
  Future<void> checkAuth() async {
    final generation = ++_authGeneration;
    _activeAuthChecks++;
    _status = AuthStatus.loading;
    _isServerVerified = false;
    notifyListeners();

    try {
      String? token;
      String? savedRole;

      // Safely access secure storage with SharedPreferences dual fallback
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

      // Restore session immediately from saved token & role before/while verifying with backend
      _status = AuthStatus.authenticated;
      if (savedRole != null && savedRole.isNotEmpty) {
        _role = savedRole;
      }
      notifyListeners();

      // Verify token with backend
      try {
        final response = await _api.get(ApiConfig.currentUser).timeout(const Duration(seconds: 4));
        if (response.data != null && response.data is Map) {
          _user = Map<String, dynamic>.from(response.data);

          // Server role is authoritative over locally cached role
          final serverRole = _user?['role'] as String?;
          if (serverRole != null && serverRole.isNotEmpty) {
            await _applyServerRole(serverRole, token);
          } else if (savedRole != null && savedRole.isNotEmpty) {
            _role = savedRole;
          }

          _status = AuthStatus.authenticated;
          _isServerVerified = true;
        } else {
          // If response format is unexpected, preserve active authenticated state
          _status = AuthStatus.authenticated;
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
          _status = AuthStatus.authenticated;
          if (savedRole != null && savedRole.isNotEmpty) {
            _role = savedRole;
          }
          _scheduleProfileRecovery(generation);
        }
      } catch (generalErr) {
        // Timeout or non-auth exception: preserve session if token exists
        _status = AuthStatus.authenticated;
        if (savedRole != null && savedRole.isNotEmpty) {
          _role = savedRole;
        }
        // A slow /auth/me (e.g. serverless cold start) must not leave the profile empty for the whole session
        _scheduleProfileRecovery(generation);
      }
    } finally {
      _activeAuthChecks--;
      _markInitialized();
      notifyListeners();
    }
  }

  /// /auth/me reports an allowlisted admin's DB role ('parent'); the admin portal session is
  /// identified by its token's `role: admin` / `is_admin` claims instead. Only called after
  /// /auth/me accepted this exact token, so the claims are server-issued, not a cached guess.
  Future<void> _applyServerRole(String serverRole, String? token) async {
    final role = _tokenHasAdminClaims(token) ? 'admin' : serverRole;
    _role = role;
    await _storage.saveRole(role);
  }

  static bool _tokenHasAdminClaims(String? token) {
    final parts = token?.split('.') ?? const <String>[];
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return payload is Map && (payload['is_admin'] == true || payload['role'] == 'admin');
    } catch (_) {
      return false;
    }
  }

  void _markInitialized() {
    _isInitialized = true;
    if (!_authInitCompleter.isCompleted) {
      _authInitCompleter.complete();
    }
  }

  void _scheduleProfileRecovery(int generation) {
    if (profileRecoveryDelays.isEmpty) return;
    unawaited(_recoverUserProfile(generation));
  }

  /// Retries /auth/me with a short bounded back-off while a restored session is still unverified.
  Future<void> _recoverUserProfile(int generation) async {
    for (final delay in profileRecoveryDelays) {
      await Future.delayed(delay);
      if (_disposed || generation != _authGeneration) return;
      if (_status != AuthStatus.authenticated || _isServerVerified) return;
      await refreshCurrentUser();
      if (_isServerVerified) return;
    }
  }

  /// Refreshes user profile and gamification stats dynamically from /auth/me without requiring relogin.
  Future<void> refreshCurrentUser() async {
    try {
      final token = await _storage.getToken();
      if (token == null || token.isEmpty) return;
      final generation = _authGeneration;

      final response = await _api.get(ApiConfig.currentUser);
      // Drop a late response if the session changed (logout / re-login / 401) while it was in flight
      if (_disposed || generation != _authGeneration || _status != AuthStatus.authenticated) return;
      final currentToken = await _storage.getToken();
      if (currentToken != token) return;

      if (response.data != null && response.data is Map) {
        _user = Map<String, dynamic>.from(response.data);
        final serverRole = _user?['role'] as String?;
        if (serverRole != null && serverRole.isNotEmpty) {
          await _applyServerRole(serverRole, token);
        }
        _isServerVerified = true;
        notifyListeners();
      }
    } catch (_) {
      // Keep existing state on transient refresh failure
    }
  }

  /// Requires fresh server verification for sensitive actions.
  /// If the session is already server-verified, returns true immediately.
  /// Otherwise attempts to verify with the backend.
  Future<bool> requireServerVerification() async {
    if (_isServerVerified && _user != null) return true;
    await refreshCurrentUser();
    return _isServerVerified;
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

  /// Test-only seam: seeds a server-verified session without network or secure storage.
  @visibleForTesting
  void debugSeedVerifiedSession({required Map<String, dynamic> user, String? role}) {
    _user = Map<String, dynamic>.from(user);
    _role = role ?? user['role'] as String?;
    _status = AuthStatus.authenticated;
    _isServerVerified = true;
    notifyListeners();
  }

  /// Test-only seam: what the interactive Google account chooser leaves behind (pending email / name).
  @visibleForTesting
  void debugSetPendingGoogleAccount({String? email, String? name}) {
    _pendingGoogleEmail = email;
    _pendingGoogleName = name;
  }

  GoogleSignIn _buildGoogleSignIn() {
    return GoogleSignIn(
      scopes: ['email', 'profile'],
      serverClientId: ApiConfig.googleServerClientId.isNotEmpty
          ? ApiConfig.googleServerClientId
          : null,
    );
  }

  /// Interactive Google sign-in used to confirm identity for Google-only parents (C13),
  /// e.g. MFA setup/disable/regenerate or re-auth when the account has no password.
  /// Returns a fresh Google ID token, or null when cancelled or unavailable (see [errorMessage]).
  Future<String?> obtainGoogleIdToken() async {
    _errorMessage = null;
    try {
      final googleSignIn = _buildGoogleSignIn();

      // Always show the account chooser so the parent explicitly confirms the account
      try {
        await googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) return null; // User cancelled flow

      final GoogleSignInAuthentication authAuth = await account.authentication;
      final idToken = authAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('لم نتمكن من الحصول على رمز التحقق (ID Token) المعتمد من Google');
      }
      return idToken;
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      notifyListeners();
      return null;
    }
  }

  // Genuine Google / Gmail Sign-in with cryptographically verified ID Token
  Future<bool> loginWithGoogle({
    String? manualIdToken,
    bool createIfMissing = false,
    String? familyName,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _isGoogleAccountUnregistered = false;
    _clearAdminMfaState(clearRecoveryCodes: true);
    notifyListeners();

    try {
      String? idToken = manualIdToken;

      if (idToken == null || idToken.isEmpty) {
        final GoogleSignIn googleSignIn = _buildGoogleSignIn();

        // Force Google account chooser dialog every time by signing out any cached local session
        try {
          await googleSignIn.signOut();
        } catch (_) {}

        final GoogleSignInAccount? account = await googleSignIn.signIn();
        if (account == null) {
          _status = AuthStatus.unauthenticated;
          notifyListeners();
          return false; // User cancelled flow
        }

        _pendingGoogleEmail = account.email;
        _pendingGoogleName = account.displayName;

        final GoogleSignInAuthentication authAuth = await account.authentication;
        idToken = authAuth.idToken;
      }

      if (idToken == null || idToken.isEmpty) {
        throw Exception('لم نتمكن من الحصول على رمز التحقق (ID Token) المعتمد من Google');
      }

      final trimmedFamilyName = familyName?.trim() ?? '';
      final response = await _api.post(
        ApiConfig.googleLogin,
        data: {
          'id_token': idToken,
          'create_if_missing': createIfMissing,
          // The family name typed on the register screen (backend caps it at 100 chars)
          if (createIfMissing && trimmedFamilyName.isNotEmpty)
            'family_name': trimmedFamilyName.length > 100
                ? trimmedFamilyName.substring(0, 100)
                : trimmedFamilyName,
        },
      );

      final data = response.data;
      if (data != null && data is Map && data['mfa_required'] == true) {
        // FF-01: Parent enabled MFA; prompt for TOTP before granting full session.
        // The temp token is kept so verifyMfa() completes the challenge exactly like the password path (C3).
        _tempLoginToken = data['temp_token']?.toString();
        _pendingParentEmail = null;
        _status = AuthStatus.requiresMfa;
        notifyListeners();
        return false;
      }

      final token = data?['access_token'];
      if (token == null || (token is String && token.isEmpty)) {
        throw Exception('لم يتم استلام رمز الدخول من الخادم');
      }

      _tempLoginToken = null;
      _pendingParentEmail = null;
      _isGoogleAccountUnregistered = false;
      _role = 'parent';

      if (data['user'] != null && data['user'] is Map) {
        _user = Map<String, dynamic>.from(data['user']);
        if (_user?['role'] != null) {
          _role = _user!['role'] as String;
        }
      }

      final saved = await _storage.saveSession(token: token, role: _role ?? 'parent');
      if (!saved) {
        throw Exception('تعذر حفظ بيانات الجلسة بشكل آمن على هذا الجهاز');
      }
      _status = AuthStatus.authenticated;
      _isServerVerified = true;
      notifyListeners();
      return await _confirmNewSession();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 404) {
        _isGoogleAccountUnregistered = true;
        final resData = e.response?.data;
        if (resData is Map && resData['detail'] != null) {
          _errorMessage = resData['detail'].toString();
        } else {
          _errorMessage = 'هذا الحساب غير مسجل بعد في FinFamily. يرجى إنشاء حساب جديد.';
        }
      } else {
        _errorMessage = ApiErrorHandler.getErrorMessage(e);
      }
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Parent Login
  Future<bool> loginParent(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _pendingParentEmail = email.trim();
    _clearAdminMfaState(clearRecoveryCodes: true);
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
      _applyLoginUser(data);

      final saved = await _storage.saveSession(token: token, role: 'parent');
      if (!saved) {
        throw Exception('تعذر حفظ بيانات الجلسة بشكل آمن على هذا الجهاز');
      }
      return await _confirmNewSession();
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Cancels any pending MFA flow, clearing sensitive pending credentials and tokens (FF-26)
  void cancelMfa() {
    _tempLoginToken = null;
    _pendingParentEmail = null;
    _pendingGoogleEmail = null;
    _pendingGoogleName = null;
    _isGoogleAccountUnregistered = false;
    _clearAdminMfaState(clearRecoveryCodes: true);
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  /// Leaves the admin MFA step (C2) and discards the in-memory challenge token.
  void cancelAdminMfa() => cancelMfa();

  /// Forgets the admin recovery codes once they have been shown to the admin.
  void clearAdminRecoveryCodes() {
    if (_adminRecoveryCodes == null) return;
    _adminRecoveryCodes = null;
    notifyListeners();
  }

  // Parent Recovery Code Login
  Future<bool> loginParentWithRecovery(String recoveryCode, {String? email, String? password}) async {
    // Recovery codes are shown as XXXX-XXXX-XXXX-XXXX; the backend accepts the compact form (C1)
    final normalizedCode = normalizeMfaCode(recoveryCode);

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    // If an MFA challenge token is active, authenticate recovery code directly without retaining password
    if (_tempLoginToken != null) {
      return verifyMfa(normalizedCode);
    }

    final targetEmail = email?.trim().toLowerCase() ?? _pendingParentEmail;
    final targetPassword = password;

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
          'recovery_code': normalizedCode,
        },
      );

      final token = response.data['access_token'];
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _applyLoginUser(response.data);

      final saved = await _storage.saveSession(token: token, role: 'parent');
      if (!saved) {
        throw Exception('تعذر حفظ بيانات الجلسة بشكل آمن على هذا الجهاز');
      }
      return await _confirmNewSession();
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      _status = AuthStatus.requiresMfa;
      notifyListeners();
      return false;
    }
  }

  // Parent MFA Verify (TOTP or recovery code, password or Google challenge)
  Future<bool> verifyMfa(String code) async {
    if (_tempLoginToken == null) {
      _errorMessage = 'انتهت مهلة التحقق الثنائي، يرجى تسجيل الدخول مجدداً';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConfig.mfaVerify,
        data: {
          'temp_token': _tempLoginToken,
          'code': normalizeMfaCode(code),
        },
      );

      final token = response.data['access_token'];
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _applyLoginUser(response.data);

      final saved = await _storage.saveSession(token: token, role: 'parent');
      if (!saved) {
        throw Exception('تعذر حفظ بيانات الجلسة بشكل آمن على هذا الجهاز');
      }
      return await _confirmNewSession();
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      if (_isDeadMfaChallenge(e)) {
        // The 5-minute challenge expired: retrying codes can never succeed, the user must log in again
        _tempLoginToken = null;
        _pendingParentEmail = null;
        _pendingGoogleEmail = null;
        _pendingGoogleName = null;
        _status = AuthStatus.unauthenticated;
      } else {
        _status = AuthStatus.requiresMfa;
      }
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
      _applyLoginUser(response.data);

      final saved = await _storage.saveSession(token: token, role: 'child');
      if (!saved) {
        throw Exception('تعذر حفظ بيانات الجلسة بشكل آمن على هذا الجهاز');
      }
      return await _confirmNewSession();
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Super Admin Login, step 1 of 2: email + password (admin MFA is mandatory on the backend).
  // Returns true ONLY when fully authenticated; on `mfa_required` it returns false with
  // status == AuthStatus.requiresMfa and the caller must collect the code for verifyAdminMfa().
  Future<bool> loginAdmin(String email, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    _clearAdminMfaState(clearRecoveryCodes: true);
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConfig.adminLogin,
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );

      final data = response.data;
      if (data is Map && data['mfa_required'] == true) {
        // The returned token is an mfa_pending challenge / enrollment token, never a session
        final challengeToken = (data['temp_token'] ?? data['access_token'])?.toString();
        if (challengeToken == null || challengeToken.isEmpty) {
          throw Exception('لم يتم استلام رمز التحقق الثنائي من الخادم');
        }
        _tempLoginToken = challengeToken;
        _pendingParentEmail = null;
        _adminMfaPending = true;
        _adminMfaEnrollmentRequired = data['mfa_enrollment_required'] == true;
        _adminMfaSecret = data['secret']?.toString();
        _adminMfaQrCode = data['qr_code']?.toString();
        _adminMfaProvisioningUri = data['provisioning_uri']?.toString();
        _status = AuthStatus.requiresMfa;
        notifyListeners();
        return false;
      }

      // Fallback for a backend that answers with a direct admin session (no MFA step)
      final token = data is Map ? data['access_token'] : null;
      if (token is! String || token.isEmpty) {
        throw Exception('لم يتم استلام رمز الدخول من الخادم');
      }
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _role = 'admin';

      final saved = await _storage.saveSession(token: token, role: 'admin');
      if (!saved) {
        throw Exception('تعذر حفظ بيانات الجلسة بشكل آمن على هذا الجهاز');
      }
      return await _confirmNewSession() && _isServerVerified;
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  // Super Admin Login, step 2 of 2: TOTP (or recovery code) for the admin MFA challenge / enrollment.
  Future<bool> verifyAdminMfa(String code) async {
    final challengeToken = _tempLoginToken;
    if (!_adminMfaPending || challengeToken == null) {
      _errorMessage = 'انتهت مهلة التحقق الثنائي، يرجى تسجيل الدخول مجدداً';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }

    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.post(
        ApiConfig.adminMfaVerify,
        data: {
          'temp_token': challengeToken,
          'code': normalizeMfaCode(code),
        },
      );

      final data = response.data;
      final token = data is Map ? data['access_token'] : null;
      if (token is! String || token.isEmpty) {
        throw Exception('لم يتم استلام رمز الدخول من الخادم');
      }

      // Recovery codes are only returned once, when the mandatory enrollment completes
      final codes = data['recovery_codes'];
      _adminRecoveryCodes = codes is List ? codes.map((c) => c.toString()).toList() : null;
      if (data['admin'] is Map) {
        _user = Map<String, dynamic>.from(data['admin']);
      }
      _role = 'admin';

      final saved = await _storage.saveSession(token: token, role: 'admin');
      if (!saved) {
        throw Exception('تعذر حفظ بيانات الجلسة بشكل آمن على هذا الجهاز');
      }
      _tempLoginToken = null;
      _pendingParentEmail = null;
      _clearAdminMfaState(clearRecoveryCodes: false);
      // Note: /auth/me reports the account's DB role, so do not rely on role == 'admin' afterwards
      return await _confirmNewSession();
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      if (_isDeadMfaChallenge(e)) {
        _tempLoginToken = null;
        _clearAdminMfaState(clearRecoveryCodes: false);
        _status = AuthStatus.unauthenticated;
      } else {
        _status = AuthStatus.requiresMfa;
      }
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
      _applyLoginUser(response.data);

      final saved = await _storage.saveSession(token: token, role: 'parent');
      if (!saved) {
        throw Exception('تعذر حفظ بيانات الجلسة بشكل آمن على هذا الجهاز');
      }
      return await _confirmNewSession();
    } catch (e) {
      _errorMessage = ApiErrorHandler.getErrorMessage(e);
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _authGeneration++;
    try {
      await _storage.clearSession();
    } catch (_) {}
    _user = null;
    _role = null;
    _isServerVerified = false;
    _tempLoginToken = null;
    _pendingParentEmail = null;
    _pendingGoogleEmail = null;
    _pendingGoogleName = null;
    _isGoogleAccountUnregistered = false;
    _clearAdminMfaState(clearRecoveryCodes: true);
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Normalizes a TOTP or recovery code before it is sent (C1/C6):
  /// Arabic-Indic digits -> ASCII, spaces and dashes removed, uppercase.
  /// `5kgh-jyrk-e9ef-paky` -> `5KGHJYRKE9EFPAKY`, `١٢٣ ٤٥٦` -> `123456`.
  static String normalizeMfaCode(String code) {
    return normalizeArabicDigits(code)
        .replaceAll(RegExp(r'[\s\-‐-―−]'), '')
        .toUpperCase();
  }

  /// Keeps the profile returned by a login/verify response, so a slow /auth/me does not leave it empty.
  void _applyLoginUser(dynamic data) {
    if (data is Map && data['user'] is Map) {
      _user = Map<String, dynamic>.from(data['user']);
    }
  }

  /// Confirms a freshly saved session with the backend.
  /// Returns true only when the session is still active afterwards (a rejected token returns false).
  Future<bool> _confirmNewSession() async {
    await checkAuth();
    if (_status == AuthStatus.authenticated) return true;
    _errorMessage ??= 'تعذر تأكيد الجلسة مع الخادم، يرجى تسجيل الدخول مجدداً';
    notifyListeners();
    return false;
  }

  /// True when the MFA challenge token itself is dead (expired / invalid), not just a wrong code.
  bool _isDeadMfaChallenge(Object e) {
    if (e is! DioException || e.response?.statusCode != 401) return false;
    final data = e.response?.data;
    final detail = (data is Map ? data['detail'] : null)?.toString().toLowerCase() ?? '';
    return detail.contains('temporary session') ||
        detail.contains('temporary admin session') ||
        detail.contains('invalid mfa token') ||
        detail.contains('mfa challenge token');
  }

  void _clearAdminMfaState({required bool clearRecoveryCodes}) {
    _adminMfaPending = false;
    _adminMfaEnrollmentRequired = false;
    _adminMfaSecret = null;
    _adminMfaQrCode = null;
    _adminMfaProvisioningUri = null;
    if (clearRecoveryCodes) {
      _adminRecoveryCodes = null;
    }
  }
}
