import '../../widgets/custom_text_field.dart';

/// أدوات تطبيع وتحقق مشتركة لشاشات الدخول (رموز TOTP، PIN، أكواد الاستعادة، رابط/رمز إعادة التعيين).
/// Pure helpers (no widgets / no network) so they can be unit-tested directly.

final RegExp _sixDigitsRegex = RegExp(r'^[0-9]{6}$');
final RegExp _recoveryCodeRegex = RegExp(r'^(?:[A-Z0-9]{8}|[A-Z0-9]{16})$');

/// Normalizes a user-typed numeric code (TOTP / PIN): maps Arabic-Indic / Persian digits
/// to ASCII and strips any whitespace the keyboard or a paste may have added.
String normalizeNumericCode(String input) {
  return normalizeArabicDigits(input).replaceAll(RegExp(r'\s'), '');
}

/// True only for exactly six ASCII digits (rejects signs like '-12345' that int.tryParse accepts).
bool isSixDigitCode(String code) => _sixDigitsRegex.hasMatch(code);

/// Normalizes an MFA recovery code (contract C1): Arabic digits → ASCII, uppercase,
/// spaces and dashes removed. 'hsg8-jwse h982-hu8k' → 'HSG8JWSEH982HU8K'.
/// Also strips the Unicode dashes (‐ ‑ ‒ – — ― −) that notes / password apps auto-convert hyphens to,
/// matching AuthState.normalizeMfaCode.
String normalizeRecoveryCode(String input) {
  return normalizeArabicDigits(input).toUpperCase().replaceAll(RegExp(r'[\s\-‐-―−]'), '');
}

/// Accepts the backend's 16-char codes (XXXX-XXXX-XXXX-XXXX) and legacy 8-char codes,
/// after [normalizeRecoveryCode].
bool isValidRecoveryCode(String normalizedCode) => _recoveryCodeRegex.hasMatch(normalizedCode);

/// Accepts either the raw reset token from the email or the whole pasted reset link
/// (…/reset-password?token=XYZ) and returns just the token (contract C12).
String extractResetToken(String input) {
  final trimmed = input.trim();
  if (!trimmed.contains('token=')) return trimmed;

  // A bare link: let Uri decode the query (a raw token_urlsafe value never contains '=')
  if (!RegExp(r'\s').hasMatch(trimmed)) {
    try {
      final fromUri = Uri.tryParse(trimmed)?.queryParameters['token'];
      if (fromUri != null && fromUri.trim().isNotEmpty) return fromUri.trim();
    } catch (_) {
      // Malformed percent-encoding in the query: fall through to the regex below
    }
  }

  // Fallback for links pasted with surrounding text or a malformed URL
  final match = RegExp(r'token=([^&\s#]+)').firstMatch(trimmed);
  if (match != null) {
    final raw = match.group(1)!;
    try {
      return Uri.decodeQueryComponent(raw);
    } catch (_) {
      return raw;
    }
  }
  return trimmed;
}

/// Child avatar reader (contract C9): `avatar` ?? `avatar_url` ?? '👦'.
/// Ignores empty values and image URLs, which cannot be rendered as an emoji Text.
String childAvatarOf(Map<dynamic, dynamic>? child) {
  if (child == null) return '👦';
  for (final key in const ['avatar', 'avatar_url']) {
    final value = child[key];
    if (value is String) {
      final v = value.trim();
      if (v.isNotEmpty && !v.contains('://') && !v.startsWith('/')) return v;
    }
  }
  return '👦';
}
