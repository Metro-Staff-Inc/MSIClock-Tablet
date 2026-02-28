import 'dart:async';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/punch.dart';
import 'logger_service.dart';

/// Service for managing local punch data storage
/// Stores all punches locally and tracks sync status
class PunchDatabaseService {
  static final PunchDatabaseService _instance =
      PunchDatabaseService._internal();
  factory PunchDatabaseService() => _instance;
  PunchDatabaseService._internal();

  Database? _database;
  final LoggerService _logger = LoggerService();

  /// Get the database instance, initializing if necessary
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'msi_clock_punches.db');

    await _logger.logInfo('Initializing punch database at: $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database schema
  Future<void> _onCreate(Database db, int version) async {
    await _logger.logInfo('Creating punch database schema');

    await db.execute('''
      CREATE TABLE punches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        image_data BLOB,
        is_synced INTEGER NOT NULL DEFAULT 0,
        first_name TEXT,
        last_name TEXT,
        punch_type TEXT,
        exception INTEGER,
        weekly_hours TEXT,
        sync_attempts INTEGER NOT NULL DEFAULT 0,
        last_sync_attempt TEXT,
        created_at TEXT NOT NULL,
        synced_at TEXT
      )
    ''');

    // Create indexes for better query performance
    await db.execute('CREATE INDEX idx_employee_id ON punches(employee_id)');
    await db.execute('CREATE INDEX idx_is_synced ON punches(is_synced)');
    await db.execute('CREATE INDEX idx_timestamp ON punches(timestamp)');
    await db.execute('CREATE INDEX idx_created_at ON punches(created_at)');

    await _logger.logInfo('Punch database schema created successfully');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await _logger.logInfo(
      'Upgrading punch database from version $oldVersion to $newVersion',
    );
    // Add migration logic here if schema changes in future versions
  }

  /// Insert a new punch into the database
  Future<int> insertPunch(Punch punch) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      final id = await db.insert('punches', {
        'employee_id': punch.employeeId,
        'timestamp': punch.timestamp.toIso8601String(),
        'image_data': punch.imageData,
        'is_synced': punch.isSynced ? 1 : 0,
        'first_name': punch.firstName,
        'last_name': punch.lastName,
        'punch_type': punch.punchType,
        'exception': punch.exception,
        'weekly_hours': punch.weeklyHours,
        'sync_attempts': 0,
        'last_sync_attempt': null,
        'created_at': now,
        'synced_at': punch.isSynced ? now : null,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await _logger.logPunch(
        'Stored punch in database: ID=$id, Employee=${punch.employeeId}, Synced=${punch.isSynced}',
      );

      return id;
    } catch (e) {
      await _logger.logError('Failed to insert punch into database: $e');
      rethrow;
    }
  }

  /// Update a punch's sync status
  Future<void> updatePunchSyncStatus({
    required int id,
    required bool isSynced,
    String? firstName,
    String? lastName,
    String? punchType,
    int? exception,
    String? weeklyHours,
  }) async {
    try {
      final db = await database;
      final now = DateTime.now().toIso8601String();

      final updateData = <String, dynamic>{
        'is_synced': isSynced ? 1 : 0,
        'last_sync_attempt': now,
      };

      if (isSynced) {
        updateData['synced_at'] = now;
      }

      // Update server response data if provided
      if (firstName != null) updateData['first_name'] = firstName;
      if (lastName != null) updateData['last_name'] = lastName;
      if (punchType != null) updateData['punch_type'] = punchType;
      if (exception != null) updateData['exception'] = exception;
      if (weeklyHours != null) updateData['weekly_hours'] = weeklyHours;

      await db.update('punches', updateData, where: 'id = ?', whereArgs: [id]);

      await _logger.logPunch(
        'Updated punch sync status: ID=$id, Synced=$isSynced',
      );
    } catch (e) {
      await _logger.logError('Failed to update punch sync status: $e');
      rethrow;
    }
  }

  /// Increment sync attempt counter
  Future<void> incrementSyncAttempts(int id) async {
    try {
      final db = await database;
      await db.rawUpdate(
        'UPDATE punches SET sync_attempts = sync_attempts + 1, last_sync_attempt = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), id],
      );
    } catch (e) {
      await _logger.logError('Failed to increment sync attempts: $e');
    }
  }

  /// Get all unsynced punches
  Future<List<Map<String, dynamic>>> getUnsyncedPunches() async {
    try {
      final db = await database;
      final results = await db.query(
        'punches',
        where: 'is_synced = ?',
        whereArgs: [0],
        orderBy: 'timestamp ASC',
      );

      await _logger.logDebug('Found ${results.length} unsynced punches');
      return results;
    } catch (e) {
      await _logger.logError('Failed to get unsynced punches: $e');
      return [];
    }
  }

  /// Get all punches (for export)
  Future<List<Map<String, dynamic>>> getAllPunches() async {
    try {
      final db = await database;
      final results = await db.query('punches', orderBy: 'timestamp DESC');

      await _logger.logDebug('Retrieved ${results.length} total punches');
      return results;
    } catch (e) {
      await _logger.logError('Failed to get all punches: $e');
      return [];
    }
  }

  /// Get punches within a date range
  Future<List<Map<String, dynamic>>> getPunchesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final db = await database;
      final results = await db.query(
        'punches',
        where: 'timestamp >= ? AND timestamp <= ?',
        whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
        orderBy: 'timestamp DESC',
      );

      return results;
    } catch (e) {
      await _logger.logError('Failed to get punches by date range: $e');
      return [];
    }
  }

  /// Delete punches older than the specified number of days
  Future<int> deleteOldPunches(int retentionDays) async {
    try {
      final db = await database;
      final cutoffDate =
          DateTime.now()
              .subtract(Duration(days: retentionDays))
              .toIso8601String();

      final deletedCount = await db.delete(
        'punches',
        where: 'created_at < ?',
        whereArgs: [cutoffDate],
      );

      await _logger.logInfo(
        'Deleted $deletedCount punches older than $retentionDays days',
      );

      return deletedCount;
    } catch (e) {
      await _logger.logError('Failed to delete old punches: $e');
      return 0;
    }
  }

  /// Get database statistics
  Future<Map<String, int>> getStatistics() async {
    try {
      final db = await database;

      final totalResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM punches',
      );
      final total = Sqflite.firstIntValue(totalResult) ?? 0;

      final syncedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM punches WHERE is_synced = 1',
      );
      final synced = Sqflite.firstIntValue(syncedResult) ?? 0;

      final unsyncedResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM punches WHERE is_synced = 0',
      );
      final unsynced = Sqflite.firstIntValue(unsyncedResult) ?? 0;

      return {'total': total, 'synced': synced, 'unsynced': unsynced};
    } catch (e) {
      await _logger.logError('Failed to get database statistics: $e');
      return {'total': 0, 'synced': 0, 'unsynced': 0};
    }
  }

  /// Export all punches to a human-readable text format
  Future<String> exportToText() async {
    try {
      final punches = await getAllPunches();
      final stats = await getStatistics();

      final buffer = StringBuffer();
      buffer.writeln('=' * 80);
      buffer.writeln('MSI CLOCK - PUNCH DATABASE EXPORT');
      buffer.writeln('=' * 80);
      buffer.writeln('Export Date: ${DateTime.now()}');
      buffer.writeln('Total Punches: ${stats['total']}');
      buffer.writeln('Synced: ${stats['synced']}');
      buffer.writeln('Unsynced: ${stats['unsynced']}');
      buffer.writeln('=' * 80);
      buffer.writeln();

      if (punches.isEmpty) {
        buffer.writeln('No punches found in database.');
      } else {
        for (final punch in punches) {
          buffer.writeln('-' * 80);
          buffer.writeln('Punch ID: ${punch['id']}');
          buffer.writeln('Employee ID: ${punch['employee_id']}');
          buffer.writeln('Timestamp: ${punch['timestamp']}');
          buffer.writeln('Created At: ${punch['created_at']}');
          buffer.writeln('Synced: ${punch['is_synced'] == 1 ? 'Yes' : 'No'}');

          if (punch['synced_at'] != null) {
            buffer.writeln('Synced At: ${punch['synced_at']}');
          }

          if (punch['first_name'] != null || punch['last_name'] != null) {
            buffer.writeln(
              'Name: ${punch['first_name'] ?? ''} ${punch['last_name'] ?? ''}',
            );
          }

          if (punch['exception'] != null && punch['exception'] != 0) {
            buffer.writeln('Exception: ${punch['exception']}');
          }

          buffer.writeln('Sync Attempts: ${punch['sync_attempts']}');

          if (punch['last_sync_attempt'] != null) {
            buffer.writeln('Last Sync Attempt: ${punch['last_sync_attempt']}');
          }

          // Generate image filename if image exists
          if (punch['image_data'] != null) {
            final imageFilename = _generateImageFilename(
              punch['employee_id'] as String,
              DateTime.parse(punch['timestamp'] as String),
            );
            buffer.writeln('Image Filename: $imageFilename');
          }
          buffer.writeln();
        }
      }

      buffer.writeln('=' * 80);
      buffer.writeln('END OF EXPORT');
      buffer.writeln('=' * 80);

      await _logger.logInfo(
        'Exported ${punches.length} punches to text format',
      );

      return buffer.toString();
    } catch (e) {
      await _logger.logError('Failed to export punches to text: $e');
      rethrow;
    }
  }

  /// Export all punches to CSV format
  Future<String> exportToCSV() async {
    try {
      final punches = await getAllPunches();

      final buffer = StringBuffer();

      // CSV Header
      buffer.writeln(
        'Punch ID,Employee ID,Timestamp,Created At,Synced,Synced At,'
        'First Name,Last Name,Exception,Sync Attempts,Last Sync Attempt,Image Filename',
      );

      // CSV Data
      for (final punch in punches) {
        final fields = [
          punch['id'].toString(),
          _escapeCsvField(punch['employee_id'] as String),
          _escapeCsvField(punch['timestamp'] as String),
          _escapeCsvField(punch['created_at'] as String),
          punch['is_synced'] == 1 ? 'Yes' : 'No',
          _escapeCsvField(punch['synced_at'] as String? ?? ''),
          _escapeCsvField(punch['first_name'] as String? ?? ''),
          _escapeCsvField(punch['last_name'] as String? ?? ''),
          punch['exception']?.toString() ?? '',
          punch['sync_attempts'].toString(),
          _escapeCsvField(punch['last_sync_attempt'] as String? ?? ''),
          punch['image_data'] != null
              ? _generateImageFilename(
                punch['employee_id'] as String,
                DateTime.parse(punch['timestamp'] as String),
              )
              : '',
        ];
        buffer.writeln(fields.join(','));
      }

      await _logger.logInfo('Exported ${punches.length} punches to CSV format');

      return buffer.toString();
    } catch (e) {
      await _logger.logError('Failed to export punches to CSV: $e');
      rethrow;
    }
  }

  /// Helper method to escape CSV fields
  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  /// Helper method to generate image filename
  String _generateImageFilename(String employeeId, DateTime timestamp) {
    final formattedTimestamp =
        '${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}_'
        '${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';
    return '${employeeId}__$formattedTimestamp.jpg';
  }

  /// Clear all punches from the database
  Future<int> clearAllPunches() async {
    try {
      final db = await database;
      final deletedCount = await db.delete('punches');

      await _logger.logInfo(
        'Cleared all punches from database: $deletedCount rows deleted',
      );

      return deletedCount;
    } catch (e) {
      await _logger.logError('Failed to clear database: $e');
      rethrow;
    }
  }

  /// Convert database row to Punch object
  Punch rowToPunch(Map<String, dynamic> row) {
    return Punch(
      employeeId: row['employee_id'] as String,
      timestamp: DateTime.parse(row['timestamp'] as String),
      imageData: row['image_data'] as Uint8List?,
      isSynced: (row['is_synced'] as int) == 1,
      firstName: row['first_name'] as String?,
      lastName: row['last_name'] as String?,
      punchType: row['punch_type'] as String?,
      exception: row['exception'] as int?,
      weeklyHours: row['weekly_hours'] as String?,
    );
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
    await _logger.logInfo('Punch database closed');
  }
}
