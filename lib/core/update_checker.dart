import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import 'api_client.dart';

class UpdateChecker {
  // Current installed app version & build
  static const String currentVersion = '1.0.0';
  static const int currentBuildNumber = 1;

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final res = await ApiClient().get(ApiConfig.appVersion);
      final data = res.data;

      final latestBuild = (data['build_number'] as num?)?.toInt() ?? 1;
      final latestVersion = data['latest_version'] ?? '1.0.0';
      final downloadUrl = data['download_url'] ??
          'https://github.com/Mahmoud-Hashim-pro/finfamily-mobile-app/releases/latest';
      final releaseNotes = data['release_notes'] ??
          'يتضمن هذا التحديث تحسينات أمنية وإصلاحات وإلغاء البيانات التجريبية.';
      final isMandatory = (data['is_mandatory'] as bool?) ?? false;

      final hasUpdate = latestBuild > currentBuildNumber ||
          latestVersion != currentVersion;

      if (hasUpdate && context.mounted) {
        _showUpdateDialog(
          context,
          latestVersion: latestVersion,
          downloadUrl: downloadUrl,
          releaseNotes: releaseNotes,
          isMandatory: isMandatory,
        );
      }
    } catch (_) {
      // Silent catch if offline or timeout, so it does not block app usage
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String latestVersion,
    required String downloadUrl,
    required String releaseNotes,
    required bool isMandatory,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isMandatory,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.emerald.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Text('🚀', style: TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'تحديث جديد متوفر!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.gold),
              ),
              child: Text(
                'إصدار جديد: v$latestVersion (الحالي: v$currentVersion)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              releaseNotes,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'اضغط على الزر أدناه لتنزيل التحديث وتثبيته مباشرة على هاتفك.',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          if (!isMandatory)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'لاحقاً',
                style: TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              final uri = Uri.parse(downloadUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            icon: const Icon(Icons.download, size: 18),
            label: const Text(
              'تحديث وتثبيت الآن ⬇️',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
