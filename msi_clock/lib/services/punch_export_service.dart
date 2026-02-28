import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'punch_database_service.dart';
import 'logger_service.dart';
import 'settings_service.dart';

/// Service for exporting punch database and uploading to Cloudflare R2
class PunchExportService {
  static final PunchExportService _instance = PunchExportService._internal();
  factory PunchExportService() => _instance;
  PunchExportService._internal();

  final PunchDatabaseService _database = PunchDatabaseService();
  final LoggerService _logger = LoggerService();
  final SettingsService _settings = SettingsService();

  /// Export punch database to both TXT and CSV files
  Future<Map<String, File>> exportToFiles() async {
    try {
      await _logger.logInfo('Starting punch database export');

      // Get device name from settings
      final deviceName = await _settings.getDeviceName();

      // Create filename with device name and date: {DeviceName}-YYYY-MM-DD
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final baseFilename = '$deviceName-PunchExport-$dateStr';

      // Create export directory
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/punch_exports');
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      // Export to TXT
      final exportText = await _database.exportToText();
      final txtFile = File('${exportDir.path}/$baseFilename.txt');
      await txtFile.writeAsString(exportText);
      await _logger.logInfo('TXT export saved to: ${txtFile.path}');

      // Export to CSV
      final exportCsv = await _database.exportToCSV();
      final csvFile = File('${exportDir.path}/$baseFilename.csv');
      await csvFile.writeAsString(exportCsv);
      await _logger.logInfo('CSV export saved to: ${csvFile.path}');

      return {'txt': txtFile, 'csv': csvFile};
    } catch (e) {
      await _logger.logError('Failed to export punch database: $e');
      rethrow;
    }
  }

  /// Upload export file to Cloudflare R2
  Future<bool> uploadToR2(File exportFile) async {
    try {
      await _logger.logInfo(
        'Starting upload to Cloudflare R2: ${exportFile.path}',
      );

      // Get R2 configuration
      final r2Config = await _settings.getR2Config();
      if (r2Config == null) {
        await _logger.logError('R2 configuration not found');
        return false;
      }

      final accountId = r2Config['accountId'] as String;
      final bucketName = r2Config['bucketName'] as String;
      final accessKeyId = r2Config['accessKeyId'] as String;
      final secretAccessKey = r2Config['secretAccessKey'] as String;

      // Read file content
      final fileBytes = await exportFile.readAsBytes();
      final fileName = exportFile.path.split(Platform.pathSeparator).last;

      // Construct the R2 endpoint URL
      final endpoint =
          'https://$accountId.r2.cloudflarestorage.com/$bucketName/$fileName';

      // Get current date for AWS signature
      final now = DateTime.now().toUtc();
      final dateStamp = DateFormat('yyyyMMdd').format(now);
      final amzDate = DateFormat("yyyyMMdd'T'HHmmss'Z'").format(now);

      // Create canonical request
      final method = 'PUT';
      final canonicalUri = '/$bucketName/$fileName';
      final canonicalQueryString = '';
      final payloadHash = sha256.convert(fileBytes).toString();

      final canonicalHeaders =
          'host:$accountId.r2.cloudflarestorage.com\n'
          'x-amz-content-sha256:$payloadHash\n'
          'x-amz-date:$amzDate\n';

      final signedHeaders = 'host;x-amz-content-sha256;x-amz-date';

      final canonicalRequest =
          '$method\n'
          '$canonicalUri\n'
          '$canonicalQueryString\n'
          '$canonicalHeaders\n'
          '$signedHeaders\n'
          '$payloadHash';

      // Create string to sign
      final algorithm = 'AWS4-HMAC-SHA256';
      final credentialScope = '$dateStamp/auto/s3/aws4_request';
      final stringToSign =
          '$algorithm\n'
          '$amzDate\n'
          '$credentialScope\n'
          '${sha256.convert(utf8.encode(canonicalRequest))}';

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

      // Determine content type based on file extension
      final contentType = fileName.endsWith('.csv') ? 'text/csv' : 'text/plain';

      // Make the request
      final response = await http.put(
        Uri.parse(endpoint),
        headers: {
          'Host': '$accountId.r2.cloudflarestorage.com',
          'x-amz-content-sha256': payloadHash,
          'x-amz-date': amzDate,
          'Authorization': authorization,
          'Content-Type': contentType,
        },
        body: fileBytes,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        await _logger.logInfo('Successfully uploaded to R2: $fileName');
        return true;
      } else {
        await _logger.logError(
          'Failed to upload to R2: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      await _logger.logError('Error uploading to R2: $e');
      return false;
    }
  }

  /// Export and upload both files in one operation
  Future<Map<String, dynamic>> exportAndUpload() async {
    try {
      // Export to both files
      final exportFiles = await exportToFiles();

      // Upload both files to R2
      final txtUploadSuccess = await uploadToR2(exportFiles['txt']!);
      final csvUploadSuccess = await uploadToR2(exportFiles['csv']!);

      final bothSuccess = txtUploadSuccess && csvUploadSuccess;

      return {
        'success': bothSuccess,
        'txtSuccess': txtUploadSuccess,
        'csvSuccess': csvUploadSuccess,
        'txtPath': exportFiles['txt']!.path,
        'csvPath': exportFiles['csv']!.path,
        'txtFileName':
            exportFiles['txt']!.path.split(Platform.pathSeparator).last,
        'csvFileName':
            exportFiles['csv']!.path.split(Platform.pathSeparator).last,
      };
    } catch (e) {
      await _logger.logError('Error during export and upload: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Helper method for HMAC-SHA256
  List<int> _hmacSha256(List<int> key, String data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(utf8.encode(data)).bytes;
  }

  /// Helper method to convert bytes to hex string
  String _bytesToHex(List<int> bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Get list of all export files
  Future<List<File>> getExportFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${directory.path}/punch_exports');

      if (!await exportDir.exists()) {
        return [];
      }

      final files =
          await exportDir
              .list()
              .where(
                (entity) =>
                    entity is File &&
                    (entity.path.endsWith('.txt') ||
                        entity.path.endsWith('.csv')),
              )
              .cast<File>()
              .toList();

      // Sort by modification time (newest first)
      files.sort(
        (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()),
      );

      return files;
    } catch (e) {
      await _logger.logError('Failed to get export files: $e');
      return [];
    }
  }

  /// Delete old export files (keep only last 5 pairs)
  Future<void> cleanupOldExports() async {
    try {
      final files = await getExportFiles();

      // Keep last 10 files (5 pairs of txt+csv)
      if (files.length > 10) {
        // Delete all but the 10 most recent
        for (var i = 10; i < files.length; i++) {
          await files[i].delete();
          await _logger.logInfo('Deleted old export: ${files[i].path}');
        }
      }
    } catch (e) {
      await _logger.logError('Failed to cleanup old exports: $e');
    }
  }
}
