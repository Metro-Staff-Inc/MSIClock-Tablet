import 'dart:async';
import 'dart:typed_data';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'punch_database_service.dart';
import 'soap_service.dart';
import 'logger_service.dart';
import 'settings_service.dart';
import '../models/soap_config.dart';

/// Service for syncing unsynced punches with the SOAP server
/// Monitors connectivity and automatically retries failed punches
class PunchSyncService {
  static final PunchSyncService _instance = PunchSyncService._internal();
  factory PunchSyncService() => _instance;
  PunchSyncService._internal();

  final PunchDatabaseService _database = PunchDatabaseService();
  final LoggerService _logger = LoggerService();
  final SettingsService _settings = SettingsService();

  SoapService? _soapService;
  Timer? _syncTimer;
  Timer? _cleanupTimer;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _isInitialized = false;

  /// Initialize the sync service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _logger.logInfo('Initializing punch sync service');

      // Load SOAP configuration
      final soapConfig = await _settings.getSoapConfig();
      _soapService = SoapService(soapConfig);

      // Listen to connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        _onConnectivityChanged,
      );

      // Start periodic sync timer (every 5 minutes)
      _startPeriodicSync();

      // Start daily cleanup timer (runs at 3 AM daily)
      _startDailyCleanup();

      // Perform initial sync
      await syncUnsyncedPunches();

      // Perform initial cleanup on startup
      await cleanupOldPunches();

      _isInitialized = true;
      await _logger.logInfo('Punch sync service initialized successfully');
    } catch (e) {
      await _logger.logError('Failed to initialize punch sync service: $e');
    }
  }

  /// Start periodic sync timer
  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncUnsyncedPunches();
    });
  }

  /// Start daily cleanup timer (runs at 3 AM daily)
  void _startDailyCleanup() {
    _cleanupTimer?.cancel();

    // Calculate time until next 3 AM
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 3, 0);

    // If 3 AM has already passed today, schedule for tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    final timeUntilCleanup = scheduledTime.difference(now);

    _logger.logInfo(
      'Scheduling daily database cleanup at ${scheduledTime.toString()} '
      '(in ${timeUntilCleanup.inHours} hours)',
    );

    // Schedule the first cleanup
    Timer(timeUntilCleanup, () {
      cleanupOldPunches();
      // Then schedule it to repeat every 24 hours
      _cleanupTimer = Timer.periodic(const Duration(days: 1), (_) {
        cleanupOldPunches();
      });
    });
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    // Check if we have connectivity (not none or bluetooth)
    final hasConnectivity =
        result != ConnectivityResult.none &&
        result != ConnectivityResult.bluetooth;

    if (hasConnectivity) {
      _logger.logInfo('Connectivity restored, triggering sync');
      // Trigger sync when connectivity is restored
      syncUnsyncedPunches();
    }
  }

  /// Sync all unsynced punches
  Future<Map<String, int>> syncUnsyncedPunches() async {
    if (_isSyncing) {
      await _logger.logDebug('Sync already in progress, skipping');
      return {'attempted': 0, 'succeeded': 0, 'failed': 0};
    }

    if (_soapService == null) {
      await _logger.logWarning('SOAP service not initialized, skipping sync');
      return {'attempted': 0, 'succeeded': 0, 'failed': 0};
    }

    _isSyncing = true;
    int attempted = 0;
    int succeeded = 0;
    int failed = 0;

    try {
      await _logger.logInfo('Starting punch sync');

      // Check connectivity first
      final isOnline = await _soapService!.checkConnectivity();
      if (!isOnline) {
        await _logger.logInfo('No connectivity, skipping sync');
        return {'attempted': 0, 'succeeded': 0, 'failed': 0};
      }

      // Get all unsynced punches
      final unsyncedPunches = await _database.getUnsyncedPunches();

      if (unsyncedPunches.isEmpty) {
        await _logger.logDebug('No unsynced punches to sync');
        return {'attempted': 0, 'succeeded': 0, 'failed': 0};
      }

      await _logger.logInfo(
        'Found ${unsyncedPunches.length} unsynced punches to sync',
      );

      // Sync each punch
      for (final punchRow in unsyncedPunches) {
        attempted++;
        final punchId = punchRow['id'] as int;
        final employeeId = punchRow['employee_id'] as String;
        final timestamp = DateTime.parse(punchRow['timestamp'] as String);
        final imageData = punchRow['image_data'] as Uint8List?;

        try {
          await _logger.logDebug(
            'Attempting to sync punch ID=$punchId, Employee=$employeeId',
          );

          // Increment sync attempts
          await _database.incrementSyncAttempts(punchId);

          // Attempt to record the punch with the SOAP service
          final response = await _soapService!.recordPunch(
            employeeId: employeeId,
            punchTime: timestamp,
            imageData: imageData,
            imageTimestamp: timestamp,
          );

          // Check if the sync was successful
          if (response['success'] == true && response['offline'] != true) {
            // Update the punch as synced
            await _database.updatePunchSyncStatus(
              id: punchId,
              isSynced: true,
              firstName: response['firstName'] as String?,
              lastName: response['lastName'] as String?,
              punchType: response['punchType'] as String?,
              exception: response['exception'] as int?,
              weeklyHours: response['weeklyHours'] as String?,
            );

            succeeded++;
            await _logger.logPunch(
              'Successfully synced punch ID=$punchId, Employee=$employeeId',
            );
          } else {
            failed++;
            await _logger.logWarning(
              'Failed to sync punch ID=$punchId: Server returned offline or error response',
            );
          }
        } catch (e) {
          failed++;
          await _logger.logError(
            'Error syncing punch ID=$punchId, Employee=$employeeId: $e',
          );
        }

        // Add a small delay between syncs to avoid overwhelming the server
        await Future.delayed(const Duration(milliseconds: 500));
      }

      await _logger.logInfo(
        'Sync completed: Attempted=$attempted, Succeeded=$succeeded, Failed=$failed',
      );

      return {'attempted': attempted, 'succeeded': succeeded, 'failed': failed};
    } catch (e) {
      await _logger.logError('Error during punch sync: $e');
      return {'attempted': attempted, 'succeeded': succeeded, 'failed': failed};
    } finally {
      _isSyncing = false;
    }
  }

  /// Manually trigger a sync (for testing or admin panel)
  Future<Map<String, int>> manualSync() async {
    await _logger.logInfo('Manual sync triggered');
    return await syncUnsyncedPunches();
  }

  /// Update SOAP configuration
  Future<void> updateSoapConfig(SoapConfig newConfig) async {
    try {
      _soapService?.dispose();
      _soapService = SoapService(newConfig);
      await _logger.logInfo('Punch sync service SOAP config updated');
    } catch (e) {
      await _logger.logError('Failed to update SOAP config: $e');
    }
  }

  /// Clean up old punches based on retention period
  Future<int> cleanupOldPunches() async {
    try {
      // Get retention period from settings (default 30 days)
      final settings = await _settings.loadSettings();
      final retentionDays = settings['punchRetentionDays'] as int? ?? 30;

      await _logger.logInfo(
        'Cleaning up punches older than $retentionDays days',
      );

      final deletedCount = await _database.deleteOldPunches(retentionDays);

      await _logger.logInfo('Cleanup completed: Deleted $deletedCount punches');

      return deletedCount;
    } catch (e) {
      await _logger.logError('Error during cleanup: $e');
      return 0;
    }
  }

  /// Get sync statistics
  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final dbStats = await _database.getStatistics();
      final isOnline = _soapService?.isOnline ?? false;

      return {...dbStats, 'isOnline': isOnline, 'isSyncing': _isSyncing};
    } catch (e) {
      await _logger.logError('Failed to get sync statistics: $e');
      return {
        'total': 0,
        'synced': 0,
        'unsynced': 0,
        'isOnline': false,
        'isSyncing': false,
      };
    }
  }

  /// Dispose of the service
  void dispose() {
    _syncTimer?.cancel();
    _cleanupTimer?.cancel();
    _connectivitySubscription?.cancel();
    _soapService?.dispose();
    _isInitialized = false;
    _logger.logInfo('Punch sync service disposed');
  }
}
