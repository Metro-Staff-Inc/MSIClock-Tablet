import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for checking app updates from GitHub releases
class UpdateService {
  // GitHub API URL for releases
  // Replace with your actual repository owner and name
  static const String githubApiUrl =
      'https://api.github.com/repos/metro-staff-inc/MSIClock-Tablet/releases/latest';

  static const String prefsLastCheckKey = 'last_update_check';
  static const Duration checkInterval = Duration(days: 1);

  final Dio _dio = Dio();

  /// Check if it's time for a scheduled update check
  Future<bool> shouldCheckForUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final lastCheck = prefs.getInt(prefsLastCheckKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    return now - lastCheck > checkInterval.inMilliseconds;
  }

  /// Update the last check timestamp
  Future<void> updateLastCheckTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      prefsLastCheckKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Get the current app version
  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  /// Check if an update is available
  /// Returns a tuple (isUpdateAvailable, latestVersion, downloadUrl, releaseNotes)
  Future<Map<String, dynamic>> checkForUpdate() async {
    try {
      // Update the last check time
      await updateLastCheckTime();

      // Get current version
      final currentVersion = await getCurrentVersion();

      // Fetch latest release from GitHub
      final response = await http.get(Uri.parse(githubApiUrl));

      if (response.statusCode != 200) {
        return {
          'isUpdateAvailable': false,
          'error': 'Failed to check for updates: ${response.statusCode}',
        };
      }

      final releaseData = jsonDecode(response.body);
      final latestVersion =
          releaseData['tag_name']?.toString().replaceAll('v', '') ?? '';
      final downloadUrl =
          releaseData['assets']?.firstWhere(
            (asset) => asset['name'].toString().endsWith('.apk'),
            orElse: () => null,
          )?['browser_download_url'];

      final releaseNotes = releaseData['body'] ?? '';

      // Simple version comparison (can be enhanced for more complex versioning)
      final isUpdateAvailable = isNewerVersion(currentVersion, latestVersion);

      return {
        'isUpdateAvailable': isUpdateAvailable,
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'downloadUrl': downloadUrl,
        'releaseNotes': releaseNotes,
      };
    } catch (e) {
      return {
        'isUpdateAvailable': false,
        'error': 'Error checking for updates: $e',
      };
    }
  }

  /// Compare version strings to determine if latest is newer than current
  bool isNewerVersion(String currentVersion, String latestVersion) {
    if (currentVersion == latestVersion) return false;

    final current = currentVersion.split('.');
    final latest = latestVersion.split('.');

    // Compare major, minor, patch versions
    for (int i = 0; i < latest.length && i < current.length; i++) {
      final currentPart = int.tryParse(current[i]) ?? 0;
      final latestPart = int.tryParse(latest[i]) ?? 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    // If all comparable parts are equal, the longer version is newer
    return latest.length > current.length;
  }

  /// Schedule a daily check at 1:00 AM
  Future<void> scheduleUpdateCheck() async {
    // Calculate time until next 1:00 AM
    final now = DateTime.now();
    final next1AM = DateTime(
      now.year,
      now.month,
      // If it's already past 1 AM, schedule for tomorrow
      now.hour >= 1 ? now.day + 1 : now.day,
      1, // 1 AM
      0, // 0 minutes
    );

    // Calculate the duration until 1 AM
    final duration = next1AM.difference(now);
    print(
      'Next update check scheduled in ${duration.inHours} hours and ${duration.inMinutes % 60} minutes',
    );

    // Schedule the task
    Future.delayed(duration, () async {
      print('Scheduled update check running at ${DateTime.now()}');
      await checkAndAutoUpdate();

      // Reschedule for the next day after this check is complete
      scheduleUpdateCheck();
    });
  }

  /// Check for updates and install automatically without user interaction
  Future<void> checkAndAutoUpdate() async {
    try {
      print('Performing automatic update check at ${DateTime.now()}');

      // Update last check time
      await updateLastCheckTime();

      // Check for updates
      final updateInfo = await checkForUpdate();

      if (updateInfo['isUpdateAvailable'] == true &&
          updateInfo['downloadUrl'] != null) {
        print(
          'Update available: ${updateInfo['latestVersion']}. Downloading automatically...',
        );

        // Download and install automatically
        await silentDownloadAndInstall(updateInfo['downloadUrl']);
      } else {
        print(
          'No updates available or error checking: ${updateInfo['error'] ?? 'No error'}',
        );
      }
    } catch (e) {
      print('Error in automatic update: $e');
    }
  }

  /// Download and install the update silently (for automatic updates)
  Future<void> silentDownloadAndInstall(String url) async {
    try {
      // Request storage permission (should already be granted for kiosk app)
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        print('Storage permission denied for automatic update');
        return;
      }

      // Get download directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('Could not access download directory for automatic update');
        return;
      }

      final savePath = '${directory.path}/msi_clock_update.apk';
      print('Downloading update to: $savePath');

      // Download the file
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            print('Download progress: ${(progress * 100).toStringAsFixed(0)}%');
          }
        },
      );

      // Install APK
      final file = File(savePath);
      if (await file.exists()) {
        print('Download complete, installing update...');
        final uri = Uri.file(file.path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          print('Update installation started');
        } else {
          print('Could not launch the installer');
        }
      } else {
        print('Download failed: File not found');
      }
    } catch (e) {
      print('Error in silent update: $e');
    }
  }

  /// Download and install the update (interactive version for manual updates)
  Future<void> downloadAndInstallUpdate(
    String url,
    Function(double) onProgress,
    Function(String) onError,
    Function() onSuccess,
  ) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        onError('Storage permission is required to download updates');
        return;
      }

      // Get download directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        onError('Could not access download directory');
        return;
      }

      final savePath = '${directory.path}/msi_clock_update.apk';

      // Download the file
      await _dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
          }
        },
      );

      // Launch the APK installer
      final file = File(savePath);
      if (await file.exists()) {
        final uri = Uri.file(file.path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          onSuccess();
        } else {
          onError('Could not launch the installer');
        }
      } else {
        onError('Download failed: File not found');
      }
    } catch (e) {
      onError('Error downloading update: $e');
    }
  }

  /// Show update dialog with custom styling
  Future<bool> showUpdateDialog(
    BuildContext context,
    Map<String, dynamic> updateInfo,
  ) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Update Available'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text(
                      'A new version (${updateInfo['latestVersion']}) is available.',
                    ),
                    const SizedBox(height: 8),
                    const Text('Release Notes:'),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        updateInfo['releaseNotes'] ??
                            'No release notes available',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Current version: ${updateInfo['currentVersion']}'),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Later'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
                ElevatedButton(
                  child: const Text('Update Now'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }
}
