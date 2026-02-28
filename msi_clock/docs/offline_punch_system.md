# Offline Punch Storage and Sync System

## Overview

The MSI Clock application now includes a comprehensive offline-first punch storage system that ensures no punch data is ever lost, even during network outages. All punches are stored locally in a SQLite database and automatically synced when connectivity is restored.

## Architecture

### Components

1. **PunchDatabaseService** (`lib/services/punch_database_service.dart`)
   - Manages local SQLite database for punch storage
   - Stores all punch data including employee info, timestamps, and images
   - Tracks sync status for each punch
   - Provides CRUD operations and statistics

2. **PunchSyncService** (`lib/services/punch_sync_service.dart`)
   - Monitors connectivity changes
   - Automatically retries unsynced punches every 5 minutes
   - Handles manual sync operations
   - Updates punch sync status after successful transmission

3. **PunchExportService** (`lib/services/punch_export_service.dart`)
   - Exports punch database to human-readable text format
   - Uploads exports to Cloudflare R2 storage
   - Manages export file cleanup

4. **Updated PunchService** (`lib/services/punch_service.dart`)
   - Now stores ALL punches locally before attempting SOAP transmission
   - Marks punches as synced/unsynced based on transmission success
   - Ensures data persistence even if SOAP fails

## How It Works

### Punch Recording Flow

1. **User punches in/out**
   - Camera captures image (if enabled)
   - Timestamp is recorded
2. **Immediate local storage**
   - Punch is stored in local SQLite database
   - Marked as `isSynced: false` initially
3. **SOAP transmission attempt**
   - Application attempts to send punch to SOAP server
   - If successful: punch is marked as `isSynced: true` in database
   - If failed: punch remains `isSynced: false` for later retry

4. **Automatic retry**
   - PunchSyncService monitors connectivity
   - Every 5 minutes, attempts to sync all unsynced punches
   - When connectivity is restored, immediate sync is triggered
   - Successfully synced punches are marked as `isSynced: true`

### Database Schema

```sql
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
```

### Indexes

- `idx_employee_id` - Fast employee lookup
- `idx_is_synced` - Quick unsynced punch queries
- `idx_timestamp` - Chronological sorting
- `idx_created_at` - Retention cleanup

## Features

### 1. Automatic Sync

- Runs every 5 minutes in the background
- Triggered immediately when connectivity is restored
- Exponential backoff for failed attempts
- Tracks sync attempt count per punch

### 2. Data Retention

- Configurable retention period (default: 30 days)
- Automatically deletes punches older than retention period
- Prevents database from growing indefinitely
- Configurable in Admin Settings

### 3. Database Export

- Export entire database to human-readable text format
- Includes all punch details and statistics
- Upload to Cloudflare R2 for backup
- Manual trigger from Admin Panel

### 4. Statistics Tracking

- Total punches stored
- Synced vs unsynced count
- Real-time updates in Admin Panel

## Admin Panel Features

### Punch Database Section

Located in the Admin Settings screen, the Punch Database section provides:

1. **Database Statistics**
   - Total punches in database
   - Number of synced punches
   - Number of unsynced punches (pending sync)

2. **Data Retention Settings**
   - Configure how many days to keep punch data
   - Default: 30 days
   - Minimum: 1 day
   - Automatic cleanup runs during sync

3. **Manual Operations**
   - **Sync Now**: Manually trigger sync of all unsynced punches
   - **Export to R2**: Export database and upload to Cloudflare R2

## Configuration

### Settings File

Punch retention period is stored in `settings.json`:

```json
{
  "punchRetentionDays": 30
}
```

### Changing Retention Period

1. Open Admin Panel (long-press logo)
2. Scroll to "Punch Database" section
3. Update "Keep Punches For (Days)" field
4. Click "Save Settings"

## Monitoring

### Check Sync Status

1. Open Admin Panel
2. View "Punch Database" section
3. Check statistics:
   - If "Unsynced" > 0, punches are waiting to sync
   - If "Unsynced" = 0, all punches are synced

### Manual Sync

If punches aren't syncing automatically:

1. Open Admin Panel
2. Scroll to "Punch Database" section
3. Click "Sync Now" button
4. Check result message

### Export Database

To backup punch data:

1. Open Admin Panel
2. Scroll to "Punch Database" section
3. Click "Export to R2" button
4. File will be uploaded to Cloudflare R2

## Troubleshooting

### Punches Not Syncing

**Symptoms**: Unsynced count keeps growing

**Possible Causes**:

1. No network connectivity
2. SOAP server unreachable
3. Invalid SOAP credentials

**Solutions**:

1. Check network connection
2. Verify SOAP endpoint in settings
3. Test connectivity with "Sync Now" button
4. Check logs for error messages

### Database Growing Too Large

**Symptoms**: App performance degradation

**Solutions**:

1. Reduce retention period in settings
2. Export and backup old data
3. Manually trigger cleanup by saving settings

### Export Failing

**Symptoms**: "Failed to export" message

**Possible Causes**:

1. R2 credentials not configured
2. Network connectivity issues
3. Insufficient storage space

**Solutions**:

1. Verify R2 credentials in Admin Panel
2. Check network connection
3. Check device storage space

## Technical Details

### Sync Algorithm

```
Every 5 minutes OR on connectivity restore:
1. Check if sync already in progress → skip if yes
2. Check SOAP connectivity → skip if offline
3. Query all unsynced punches from database
4. For each punch:
   a. Increment sync_attempts counter
   b. Attempt SOAP transmission
   c. If successful:
      - Mark as synced (is_synced = 1)
      - Record synced_at timestamp
      - Update server response data
   d. If failed:
      - Log error
      - Continue to next punch
5. Wait 500ms between punches (rate limiting)
```

### Connectivity Monitoring

The system uses `connectivity_plus` package to monitor network state:

- Listens for connectivity changes
- Triggers immediate sync when connection is restored
- Ignores Bluetooth-only connections

### Data Cleanup

Cleanup runs during sync operations:

- Queries punches older than retention period
- Deletes matching records
- Logs number of deleted punches

## Performance Considerations

### Database Size

- Each punch with image: ~50-200 KB
- 1000 punches: ~50-200 MB
- Retention period limits growth
- Regular cleanup prevents bloat

### Sync Performance

- Syncs one punch at a time (sequential)
- 500ms delay between punches
- Typical sync time: 1-2 seconds per punch
- Does not block UI operations

### Battery Impact

- Sync runs every 5 minutes
- Minimal CPU usage when idle
- Network operations only when needed
- Connectivity listener is lightweight

## Future Enhancements

Potential improvements for future versions:

1. **Batch Sync**: Send multiple punches in single request
2. **Compression**: Compress images before storage
3. **Selective Export**: Export date ranges
4. **Sync Priority**: Prioritize recent punches
5. **Conflict Resolution**: Handle duplicate punches
6. **Encryption**: Encrypt sensitive data at rest

## Migration Notes

### Upgrading from Previous Version

The new system is backward compatible:

- Existing punches continue to work
- Database is created on first launch
- No data migration needed
- Old behavior preserved for online punches

### First Launch

On first launch after upgrade:

1. Database is automatically created
2. Sync service initializes
3. All new punches are stored locally
4. No user action required

## Support

For issues or questions:

1. Check logs in Admin Panel
2. Export database for analysis
3. Review error messages in sync results
4. Contact development team with logs

---

**Version**: 1.0.0  
**Last Updated**: 2026-02-28  
**Author**: MSI Clock Development Team
