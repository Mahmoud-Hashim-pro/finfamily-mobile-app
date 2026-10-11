import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';
import '../config/theme.dart';
import 'api_client.dart';

class UpdateChecker {
  // Current installed app version & build
  static const String currentVersion = '1.0.4';
  static const int currentBuildNumber = 5;

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final res = await ApiClient().get(ApiConfig.appVersion);
      final data = res.data;

      final latestBuild = (data['build_number'] as num?)?.toInt() ?? 5;
      final latestVersion = data['latest_version'] ?? '1.0.4';
      final downloadUrl = data['download_url'] ??
          'https://github.com/Mahmoud-Hashim-pro/finfamily-mobile-app/releases/latest/download/app-release.apk';
      final releaseNotes = data['release_notes'] ??
          'يتضمن هذا التحديث تحسينات أمنية وإصلاحات وتحديثات جديدة.';
      final isMandatory = (data['is_mandatory'] as bool?) ?? false;

      final hasUpdate = latestBuild > currentBuildNumber ||
          latestVersion != currentVersion;

      if (hasUpdate && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: !isMandatory,
          builder: (ctx) => _InAppUpdateDialog(
            latestVersion: latestVersion,
            currentVersion: currentVersion,
            downloadUrl: downloadUrl,
            releaseNotes: releaseNotes,
            isMandatory: isMandatory,
          ),
        );
      }
    } catch (_) {
      // Silent catch if offline or timeout, so it does not block app usage
    }
  }
}

class _InAppUpdateDialog extends StatefulWidget {
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;
  final String releaseNotes;
  final bool isMandatory;

  const _InAppUpdateDialog({
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.isMandatory,
  });

  @override
  State<_InAppUpdateDialog> createState() => _InAppUpdateDialogState();
}

class _InAppUpdateDialogState extends State<_InAppUpdateDialog> {
  bool _isDownloading = false;
  bool _isDownloaded = false;
  double _progress = 0.0;
  String _progressText = '';
  String _statusMessage = '';
  String? _errorMessage;
  String? _downloadedFilePath;
  CancelToken? _cancelToken;

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _startInAppDownload() async {
    setState(() {
      _isDownloading = true;
      _isDownloaded = false;
      _errorMessage = null;
      _progress = 0.0;
      _progressText = '0%';
      _statusMessage = 'جاري الاتصال بالسيرفر وبدء التحميل في الخلفية...';
    });

    _cancelToken = CancelToken();

    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/FinFamily_v${widget.latestVersion}.apk';

      // Delete old incomplete APK file if exists
      final existingFile = File(savePath);
      if (await existingFile.exists()) {
        try {
          await existingFile.delete();
        } catch (_) {}
      }

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      await dio.download(
        widget.downloadUrl,
        savePath,
        cancelToken: _cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, total) {
          if (!mounted) return;
          if (total > 0) {
            final pct = received / total;
            final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMB = (total / (1024 * 1024)).toStringAsFixed(1);
            setState(() {
              _progress = pct;
              _progressText = '${(pct * 100).toInt()}% ($receivedMB MB / $totalMB MB)';
              _statusMessage = 'جاري تحميل التحديث داخل التطبيق مباشرة...';
            });
          } else {
            final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
            setState(() {
              _progressText = '$receivedMB MB';
              _statusMessage = 'جاري تنزيل ملف التحديث...';
            });
          }
        },
      );

      if (!mounted) return;

      setState(() {
        _isDownloading = false;
        _isDownloaded = true;
        _progress = 1.0;
        _downloadedFilePath = savePath;
        _statusMessage = 'تم اكتمال التحميل بنجاح! 📦 جاري فتح نافذة التثبيت...';
      });

      // Automatically launch the APK installer
      await _installApk(savePath);
    } on DioException catch (e) {
      if (!mounted) return;
      if (CancelToken.isCancel(e)) {
        setState(() {
          _isDownloading = false;
          _statusMessage = 'تم إلغاء التحميل.';
        });
        return;
      }
      setState(() {
        _isDownloading = false;
        _errorMessage = 'تعذر التنزيل المباشر: ${e.message ?? "انقطاع في الاتصال"}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isDownloading = false;
        _errorMessage = 'حدث خطأ أثناء التنزيل: $e';
      });
    }
  }

  Future<void> _installApk(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        setState(() {
          _errorMessage = 'ملف التحديث غير موجود، يرجى إعادة المحاولة.';
        });
        return;
      }

      final result = await OpenFilex.open(
        filePath,
        type: 'application/vnd.android.package-archive',
      );

      if (!mounted) return;

      if (result.type != ResultType.done) {
        setState(() {
          _statusMessage =
              'يرجى السماح بتثبيت التطبيقات من هذا المصدر في نافذة أندرويد لإتمام التحديث.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر فتح مثبت التطبيق: $e';
      });
    }
  }

  Future<void> _openExternalBrowser() async {
    final uri = Uri.parse(widget.downloadUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isDownloaded
                  ? AppTheme.emerald.withOpacity(0.15)
                  : (_isDownloading
                      ? AppTheme.coral.withOpacity(0.15)
                      : AppTheme.emerald.withOpacity(0.15)),
              shape: BoxShape.circle,
            ),
            child: Text(
              _isDownloaded ? '✅' : (_isDownloading ? '📥' : '🚀'),
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isDownloaded
                  ? 'التحديث جاهز للتثبيت!'
                  : (_isDownloading
                      ? 'جاري تنزيل التحديث...'
                      : 'تحديث جديد متوفر!'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.gold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.gold),
              ),
              child: Text(
                'إصدار جديد: v${widget.latestVersion} (الحالي: v${widget.currentVersion})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.navy,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Release notes (when not downloading)
            if (!_isDownloading && !_isDownloaded) ...[
              Text(
                widget.releaseNotes,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'سيتم تنزيل وتثبيت التحديث مباشرة في الخلفية دون الحاجة لفتح المتصفح.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],

            // Active downloading progress bar
            if (_isDownloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.emerald),
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _progressText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navy,
                    ),
                  ),
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.emerald,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
            ],

            // Downloaded successfully
            if (_isDownloaded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.emerald.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppTheme.emerald, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage.isNotEmpty
                            ? _statusMessage
                            : 'تم تنزيل التحديث بنجاح! اضغط أدناه للتثبيت.',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.emerald,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Error display
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.coral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.coral.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.coral, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.coral),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Cancel / Dismiss button
        if (!widget.isMandatory && !_isDownloading)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'لاحقاً',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ),

        // Cancel during download
        if (_isDownloading)
          TextButton(
            onPressed: () {
              _cancelToken?.cancel();
            },
            child: const Text(
              'إلغاء التحميل',
              style: TextStyle(color: AppTheme.coral),
            ),
          ),

        // Retry if error
        if (_errorMessage != null && !_isDownloading)
          TextButton.icon(
            onPressed: _openExternalBrowser,
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: const Text(
              'فتح في المتصفح',
              style: TextStyle(color: AppTheme.navy, fontSize: 12),
            ),
          ),

        // Main action button
        if (!_isDownloading && !_isDownloaded)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: _startInAppDownload,
            icon: const Icon(Icons.download, size: 18),
            label: const Text(
              'تحديث وتثبيت الآن ⬇️',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

        // Install button if already downloaded
        if (_isDownloaded && _downloadedFilePath != null)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => _installApk(_downloadedFilePath!),
            icon: const Icon(Icons.install_mobile, size: 18),
            label: const Text(
              'تثبيت التحديث الآن 🚀',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
      ],
    );
  }
}
