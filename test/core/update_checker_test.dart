import 'package:flutter_test/flutter_test.dart';
import 'package:finfamily_mobile/core/update_checker.dart';

void main() {
  group('UpdateChecker - Semantic Version Comparison (BUG-100, BUG-142)', () {
    test('detects higher patch version as update', () {
      expect(UpdateChecker.isNewerVersion('1.0.6', '1.0.5', 6, 6), isTrue);
    });

    test('detects higher minor version as update', () {
      expect(UpdateChecker.isNewerVersion('1.1.0', '1.0.5', 6, 6), isTrue);
    });

    test('detects higher major version as update', () {
      expect(UpdateChecker.isNewerVersion('2.0.0', '1.0.5', 6, 6), isTrue);
    });

    test('detects higher build number with same version as update', () {
      expect(UpdateChecker.isNewerVersion('1.0.5', '1.0.5', 7, 6), isTrue);
    });

    test('NEVER prompts for downgrade when version is older (BUG-100)', () {
      expect(UpdateChecker.isNewerVersion('1.0.4', '1.0.5', 5, 6), isFalse);
      expect(UpdateChecker.isNewerVersion('0.9.9', '1.0.5', 99, 6), isFalse);
      expect(UpdateChecker.isNewerVersion('1.0.4', '1.0.5', 6, 6), isFalse);
    });

    test('does not prompt update when version and build are identical', () {
      expect(UpdateChecker.isNewerVersion('1.0.5', '1.0.5', 6, 6), isFalse);
    });

    test('does not prompt update when build number is lower', () {
      expect(UpdateChecker.isNewerVersion('1.0.5', '1.0.5', 5, 6), isFalse);
    });

    test('handles v-prefix notation cleanly', () {
      expect(UpdateChecker.isNewerVersion('v1.0.6', 'v1.0.5', 6, 6), isTrue);
      expect(UpdateChecker.isNewerVersion('v1.0.4', 'v1.0.5', 6, 6), isFalse);
    });

    test('handles two-part versions with implied zero patch', () {
      expect(UpdateChecker.isNewerVersion('1.1', '1.0.5', 6, 6), isTrue);
      expect(UpdateChecker.isNewerVersion('1.0', '1.0.5', 6, 6), isFalse);
    });
  });

  group('UpdateChecker - Download URL Security Allowlist (BUG-051, BUG-141)', () {
    test('allows trusted GitHub releases download URL', () {
      expect(
        UpdateChecker.isAllowedDownloadUrl(
          'https://github.com/Mahmoud-Hashim-pro/finfamily-mobile-app/releases/latest/download/app-release.apk',
        ),
        isTrue,
      );
    });

    test('allows trusted GitHub user content CDN', () {
      expect(
        UpdateChecker.isAllowedDownloadUrl(
          'https://objects.githubusercontent.com/github-production-release-asset-2e65be/app-release.apk',
        ),
        isTrue,
      );
    });

    test('allows trusted FinFamily Vercel backend URL', () {
      expect(
        UpdateChecker.isAllowedDownloadUrl('https://finfamily-backend.vercel.app/updates/app-release.apk'),
        isTrue,
      );
    });

    test('allows official FinFamily domain', () {
      expect(
        UpdateChecker.isAllowedDownloadUrl('https://finfamily.app/downloads/app.apk'),
        isTrue,
      );
      expect(
        UpdateChecker.isAllowedDownloadUrl('https://api.finfamily.app/downloads/app.apk'),
        isTrue,
      );
    });

    test('REJECTS unencrypted HTTP download URL (BUG-141)', () {
      expect(
        UpdateChecker.isAllowedDownloadUrl('http://github.com/downloads/app.apk'),
        isFalse,
      );
      expect(
        UpdateChecker.isAllowedDownloadUrl('http://finfamily.app/downloads/app.apk'),
        isFalse,
      );
    });

    test('REJECTS spoofed domain containing finfamily substring (BUG-141)', () {
      expect(
        UpdateChecker.isAllowedDownloadUrl('https://evil-finfamily.com/malware.apk'),
        isFalse,
      );
      expect(
        UpdateChecker.isAllowedDownloadUrl('https://finfamily-attacker.net/app.apk'),
        isFalse,
      );
      expect(
        UpdateChecker.isAllowedDownloadUrl('https://notfinfamily.com/app.apk'),
        isFalse,
      );
    });

    test('REJECTS malformed or non-http URLs', () {
      expect(UpdateChecker.isAllowedDownloadUrl('ftp://github.com/app.apk'), isFalse);
      expect(UpdateChecker.isAllowedDownloadUrl('javascript:alert(1)'), isFalse);
      expect(UpdateChecker.isAllowedDownloadUrl(''), isFalse);
    });
  });
}
