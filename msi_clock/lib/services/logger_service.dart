import 'dart:async';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'settings_service.dart';

/// Log levels for the application
enum LogLevel {
  debug, // All logging
  normal, // Punch data only
}

/// Singleton service for application logging
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  final SettingsService _settingsService = SettingsService();
  LogLevel _currentLevel = LogLevel.normal;
  Directory? _logDirectory;
  File? _currentLogFile;
  String? _currentLogDate;
  final _logQueue = <String>[];
  bool _isWriting = false;

  /// Initialize the logger service
  Future<void> initialize() async {
    try {
      // Load log level from settings
      await _loadLogLevel();

      // Get the log directory
      _logDirectory = await _getLogDirectory();

      // Ensure log directory exists
      if (!await _logDirectory!.exists()) {
        await _logDirectory!.create(recursive: true);
      }

      // Set up current log file
      await _setupCurrentLogFile();

      // Clean up old log files
      await _cleanupOldLogs();

      // Log initialization
      await logDebug('LoggerService initialized');
    } catch (e) {
      // If initialization fails, we can't log it, so just continue
      print('Failed to initialize LoggerService: $e');
    }
  }

  /// Load log level from settings
  Future<void> _loadLogLevel() async {
    try {
      final settings = await _settingsService.loadSettings();
      final levelString = settings['logLevel'] as String? ?? 'normal';
      _currentLevel = levelString == 'debug' ? LogLevel.debug : LogLevel.normal;
    } catch (e) {
      _currentLevel = LogLevel.normal;
    }
  }

  /// Get the log directory
  Future<Directory> _getLogDirectory() async {
    // Use external storage Documents folder for easy access
    // Path: /storage/emulated/0/Documents/MSIClock/logs/
    try {
      // Request storage permission if needed (Android 10+)
      if (Platform.isAndroid) {
        final status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      }

      // Get external storage directory
      final externalDir = Directory(
        '/storage/emulated/0/Documents/MSIClock/logs',
      );

      // Create directory if it doesn't exist
      if (!await externalDir.exists()) {
        await externalDir.create(recursive: true);
      }

      return externalDir;
    } catch (e) {
      // Fallback to app documents directory if external storage fails
      print(
        'Failed to use external storage, falling back to app directory: $e',
      );
      final appDir = await getApplicationDocumentsDirectory();
      return Directory('${appDir.path}/logs');
    }
  }

  /// Set up the current log file based on today's date
  Future<void> _setupCurrentLogFile() async {
    final now = DateTime.now();
    final dateString = DateFormat('yyyy-MM-dd').format(now);

    // If the date has changed, create a new log file
    if (_currentLogDate != dateString) {
      _currentLogDate = dateString;

      // Get device name from settings
      final deviceName = await _settingsService.getDeviceName();

      // Format: {DeviceName}_YYYY-MM-DD.txt
      _currentLogFile = File(
        '${_logDirectory!.path}/${deviceName}_$dateString.txt',
      );

      // Create the file if it doesn't exist
      if (!await _currentLogFile!.exists()) {
        await _currentLogFile!.create();
        await _writeToFile('=== Log file created: $dateString ===\n');
      }
    }
  }

  /// Write a message to the log file
  Future<void> _writeToFile(String message) async {
    try {
      if (_currentLogFile != null) {
        await _currentLogFile!.writeAsString(
          message,
          mode: FileMode.append,
          flush: true,
        );
      }
    } catch (e) {
      // If we can't write to the log file, print to console
      print('Failed to write to log file: $e');
    }
  }

  /// Process the log queue
  Future<void> _processLogQueue() async {
    if (_isWriting || _logQueue.isEmpty) return;

    _isWriting = true;
    try {
      while (_logQueue.isNotEmpty) {
        final message = _logQueue.removeAt(0);
        await _writeToFile(message);
      }
    } finally {
      _isWriting = false;
    }
  }

  /// Add a log entry to the queue
  Future<void> _addLogEntry(String level, String message) async {
    try {
      // Ensure we have the current log file
      await _setupCurrentLogFile();

      final now = DateTime.now();
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(now);
      final logEntry = '[$timestamp] [$level] $message\n';

      // Add to queue
      _logQueue.add(logEntry);

      // Process queue
      await _processLogQueue();
    } catch (e) {
      print('Failed to add log entry: $e');
    }
  }

  /// Log a debug message (only if log level is DEBUG)
  Future<void> logDebug(String message) async {
    if (_currentLevel == LogLevel.debug) {
      await _addLogEntry('DEBUG', message);
    }
  }

  /// Log a punch event (logged at both DEBUG and NORMAL levels)
  Future<void> logPunch(String message) async {
    await _addLogEntry('PUNCH', message);
  }

  /// Log an error (always logged regardless of level)
  Future<void> logError(String message) async {
    await _addLogEntry('ERROR', message);
  }

  /// Log an info message (only if log level is DEBUG)
  Future<void> logInfo(String message) async {
    if (_currentLevel == LogLevel.debug) {
      await _addLogEntry('INFO', message);
    }
  }

  /// Log a warning (only if log level is DEBUG)
  Future<void> logWarning(String message) async {
    if (_currentLevel == LogLevel.debug) {
      await _addLogEntry('WARN', message);
    }
  }

  /// Clean up log files older than 10 days
  Future<void> _cleanupOldLogs() async {
    try {
      if (_logDirectory == null || !await _logDirectory!.exists()) return;

      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 10));

      final files = await _logDirectory!.list().toList();
      for (final file in files) {
        if (file is File && file.path.endsWith('.txt')) {
          // Extract date from filename (format: {DeviceName}_yyyy-MM-dd.txt)
          final filename = file.path.split('/').last;
          final match = RegExp(
            r'_(\d{4}-\d{2}-\d{2})\.txt$',
          ).firstMatch(filename);

          if (match != null) {
            final dateString = match.group(1)!;
            try {
              final fileDate = DateTime.parse(dateString);

              // Delete if older than 10 days
              if (fileDate.isBefore(cutoffDate)) {
                await file.delete();
                await logDebug('Deleted old log file: $filename');
              }
            } catch (e) {
              // If we can't parse the date, skip this file
              continue;
            }
          }
        }
      }
    } catch (e) {
      await logError('Failed to cleanup old logs: $e');
    }
  }

  /// Get all log files
  Future<List<File>> getLogFiles() async {
    try {
      if (_logDirectory == null || !await _logDirectory!.exists()) {
        return [];
      }

      final files = await _logDirectory!.list().toList();
      final logFiles =
          files
              .whereType<File>()
              .where((file) => file.path.endsWith('.txt'))
              .toList();

      // Sort by date (newest first)
      logFiles.sort((a, b) => b.path.compareTo(a.path));

      return logFiles;
    } catch (e) {
      return [];
    }
  }

  /// Get the log file for a specific date
  Future<File?> getLogFileForDate(DateTime date) async {
    try {
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      final deviceName = await _settingsService.getDeviceName();
      final file = File('${_logDirectory!.path}/${deviceName}_$dateString.txt');

      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get yesterday's log file (for upload)
  Future<File?> getYesterdayLogFile() async {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return await getLogFileForDate(yesterday);
  }

  /// Update the log level
  Future<void> setLogLevel(LogLevel level) async {
    _currentLevel = level;
    await _settingsService.updateLogLevel(
      level == LogLevel.debug ? 'debug' : 'normal',
    );
    await logInfo('Log level changed to: ${level.name}');
  }

  /// Get the current log level
  LogLevel get currentLevel => _currentLevel;

  /// Get the current log level as a string
  String get currentLevelString => _currentLevel.name;

  /// Export a log file as a string
  Future<String> exportLogFile(File file) async {
    try {
      return await file.readAsString();
    } catch (e) {
      return 'Error reading log file: $e';
    }
  }

  /// Get the log directory path
  String? get logDirectoryPath => _logDirectory?.path;
}
