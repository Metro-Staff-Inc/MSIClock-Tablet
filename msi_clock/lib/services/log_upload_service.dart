import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'logger_service.dart';
import 'settings_service.dart';

/// Service for uploading log files to Cloudflare R2
class LogUploadService {
  static final LogUploadService _instance = LogUploadService._internal();
  factory LogUploadService() => _instance;
  LogUploadService._internal();

  final LoggerService _logger = LoggerService();
  final SettingsService _settings = SettingsService();
  Timer? _uploadTimer;

  /// Initialize the upload service and schedule daily uploads at 2 AM
  Future<void> initialize() async {
    await _scheduleNextUpload();
  }

  /// Schedule the next upload at 2 AM
  Future<void> _scheduleNextUpload() async {
    // Cancel existing timer if any
    _uploadTimer?.cancel();

    // Calculate time until next 2 AM
    final now = DateTime.now();
    var next2AM = DateTime(now.year, now.month, now.day, 2, 0, 0);

    // If it's already past 2 AM today, schedule for tomorrow
    if (now.isAfter(next2AM)) {
      next2AM = next2AM.add(const Duration(days: 1));
    }

    final duration = next2AM.difference(now);

    await _logger.logDebug(
      'Next log upload scheduled for: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(next2AM)}',
    );

    // Schedule the upload
    _uploadTimer = Timer(duration, () async {
      await uploadYesterdayLog();
      // Schedule the next upload (24 hours later)
      await _scheduleNextUpload();
    });
  }

  /// Upload yesterday's log file to Cloudflare R2
  Future<bool> uploadYesterdayLog() async {
    try {
      await _logger.logInfo('Starting scheduled log upload...');

      // Get yesterday's log file
      final logFile = await _logger.getYesterdayLogFile();

      if (logFile == null || !await logFile.exists()) {
        await _logger.logWarning('No log file found for yesterday');
        return false;
      }

      // Upload the file
      final success = await uploadLogFile(logFile);

      if (success) {
        await _logger.logInfo('Successfully uploaded yesterday\'s log file');
      } else {
        await _logger.logError('Failed to upload yesterday\'s log file');
      }

      return success;
    } catch (e) {
      await _logger.logError('Error uploading yesterday\'s log: $e');
      return false;
    }
  }

  /// Upload a specific log file to Cloudflare R2
  Future<bool> uploadLogFile(File logFile) async {
    try {
      // Get R2 configuration from settings
      final settings = await _settings.loadSettings();
      final r2Config = settings['r2'] as Map<String, dynamic>?;

      if (r2Config == null) {
        await _logger.logError('R2 configuration not found in settings');
        return false;
      }

      final accountId = r2Config['accountId'] as String?;
      final bucketName = r2Config['bucketName'] as String?;
      final accessKeyId = r2Config['accessKeyId'] as String?;
      final secretAccessKey = r2Config['secretAccessKey'] as String?;

      if (accountId == null ||
          bucketName == null ||
          accessKeyId == null ||
          secretAccessKey == null) {
        await _logger.logError('Incomplete R2 configuration');
        return false;
      }

      // Read the log file
      final fileBytes = await logFile.readAsBytes();
      final fileName = logFile.path.split('/').last;

      // Generate object key (path in R2 bucket)
      final deviceName = await _settings.getDeviceName();
      final objectKey = 'logs/$deviceName/$fileName';

      // Cloudflare R2 endpoint
      final endpoint = '$accountId.r2.cloudflarestorage.com';
      final url = 'https://$endpoint/$bucketName/$objectKey';

      // Create AWS Signature Version 4
      final now = DateTime.now().toUtc();
      final dateStamp = DateFormat('yyyyMMdd').format(now);
      final amzDate = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(now);

      // Create canonical request
      final payloadHash = sha256.convert(fileBytes).toString();
      final canonicalHeaders =
          'host:$endpoint\n'
          'x-amz-content-sha256:$payloadHash\n'
          'x-amz-date:$amzDate\n';
      final signedHeaders = 'host;x-amz-content-sha256;x-amz-date';
      final canonicalRequest =
          'PUT\n'
          '/$bucketName/$objectKey\n'
          '\n'
          '$canonicalHeaders\n'
          '$signedHeaders\n'
          '$payloadHash';

      // Create string to sign
      final algorithm = 'AWS4-HMAC-SHA256';
      final credentialScope = '$dateStamp/auto/s3/aws4_request';
      final canonicalRequestHash =
          sha256.convert(utf8.encode(canonicalRequest)).toString();
      final stringToSign =
          '$algorithm\n'
          '$amzDate\n'
          '$credentialScope\n'
          '$canonicalRequestHash';

      // Calculate signature
      final kDate = _hmacSha256(utf8.encode('AWS4$secretAccessKey'), dateStamp);
      final kRegion = _hmacSha256(kDate, 'auto');
      final kService = _hmacSha256(kRegion, 's3');
      final kSigning = _hmacSha256(kService, 'aws4_request');
      final signature = _hmacSha256(kSigning, stringToSign);

      // Create authorization header
      final authorization =
          '$algorithm '
          'Credential=$accessKeyId/$credentialScope, '
          'SignedHeaders=$signedHeaders, '
          'Signature=${_bytesToHex(signature)}';

      // Upload the file
      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Host': endpoint,
          'x-amz-content-sha256': payloadHash,
          'x-amz-date': amzDate,
          'Authorization': authorization,
          'Content-Type': 'text/plain',
        },
        body: fileBytes,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _logger.logInfo('Successfully uploaded $fileName to R2');
        return true;
      } else {
        await _logger.logError(
          'Failed to upload to R2: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      await _logger.logError('Error uploading log file: $e');
      return false;
    }
  }

  /// HMAC-SHA256 helper
  List<int> _hmacSha256(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }

  /// Convert bytes to hex string
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Manually trigger an upload (for testing)
  Future<bool> manualUpload() async {
    return await uploadYesterdayLog();
  }

  /// Dispose of the service
  void dispose() {
    _uploadTimer?.cancel();
  }
}
