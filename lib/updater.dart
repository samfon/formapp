import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file_plus/open_file_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Updater {
  static const String repoOwner = 'samfon';
  static const String repoName = 'formapp';
  static const String apiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      // Get current version
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // Ensure version has 'v' prefix for comparison if github uses it
      if (!currentVersion.startsWith('v')) {
        currentVersion = 'v$currentVersion';
      }

      // Fetch latest release from GitHub
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String latestVersion = data['tag_name'];
        final String bodyText = data['body'] ?? 'Cập nhật nhỏ, tối ưu hiệu suất.';
        
        // Find APK asset URL
        String? apkDownloadUrl;
        if (data['assets'] != null && data['assets'].isNotEmpty) {
          for (var asset in data['assets']) {
            if (asset['name'].toString().endsWith('.apk')) {
              apkDownloadUrl = asset['browser_download_url'];
              break;
            }
          }
        }

        // Compare versions (simple string compare for now assuming standard semver v1.0.0)
        if (latestVersion != currentVersion && apkDownloadUrl != null) {
          if (context.mounted) {
            _showUpdateDialog(context, latestVersion, bodyText, apkDownloadUrl);
          }
        }
      }
    } catch (e) {
      debugPrint('Check for updates failed: $e');
      // Supress error for quiet background checking
    }
  }

  static void _showUpdateDialog(BuildContext context, String newVersion, String notes, String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.system_update_rounded, color: Color(0xFF1A73E8)),
              const SizedBox(width: 10),
              Flexible(child: Text('Đã có bản $newVersion', style: const TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Có bản cập nhật mới trên hệ thống với các thay đổi:',
                  style: TextStyle(fontSize: 14)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(notes, style: const TextStyle(fontSize: 13, color: Colors.black87)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Bỏ qua', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext); // close dialog
                _downloadAndInstall(context, downloadUrl, newVersion);
              },
              child: const Text('Tải & Nâng cấp ngay'),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _downloadAndInstall(BuildContext context, String url, String version) async {
    // Show download progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext progressContext) {
        return const _DownloadProgressDialog();
      },
    );

    // Request permissions
    if (Platform.isAndroid) {
      if (await Permission.requestInstallPackages.isDenied) {
        await Permission.requestInstallPackages.request();
      }
      if (await Permission.storage.isDenied) {
        await Permission.storage.request();
      }
    }

    try {
      final extDir = await getExternalStorageDirectory();
      String savePath = '${extDir!.path}/update_$version.apk';

      // Stream download via HTTP
      var request = http.Request('GET', Uri.parse(url));
      var response = await http.Client().send(request);
      
      int total = response.contentLength ?? 0;
      int received = 0;
      List<int> bytes = [];

      response.stream.listen((value) {
        bytes.addAll(value);
        received += value.length;
        // Optionally update global value notifier here to update progress UI
        // Not essential if file is small, it downloads in 1 second.
      }, onDone: () async {
        File file = File(savePath);
        await file.writeAsBytes(bytes);

        if (context.mounted) {
          Navigator.pop(context); // Close progress dialog
        }
        
        // Trigger generic OpenFile action which tells Android to install APK
        final result = await OpenFile.open(savePath);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi mở file: ${result.message}')),
          );
        }
      });
    } catch (e) {
      if (context.mounted) {
         Navigator.pop(context); // Close progress dialog
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tải xuống thất bại: $e')),
         );
      }
    }
  }
}

class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đang tải bản cập nhật...'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 10),
          LinearProgressIndicator(),
          SizedBox(height: 16),
          Text("Vui lòng không thoát ứng dụng", style: TextStyle(fontSize: 13, color: Colors.grey)),
        ],
      ),
    );
  }
}
