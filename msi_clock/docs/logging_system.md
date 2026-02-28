# Logging System Documentation

## Overview

The MSI Clock application now includes a comprehensive logging system that captures application events, punch data, and errors. Logs are automatically managed, rotated daily, and uploaded to Cloudflare R2 for long-term storage.

## Features

### 1. **Two Log Levels**

- **NORMAL** (Default): Logs only punch-related events
  - Employee punch attempts
  - Punch successes and failures
  - Exception codes
  - Punch types (check-in/check-out)

- **DEBUG**: Logs all application events
  - All NORMAL level logs
  - Application startup/shutdown
  - Camera initialization
  - SOAP service calls and timing
  - Network connectivity checks
  - Performance metrics
  - Warnings and errors

### 2. **Daily Log Rotation**

- Each day creates a new log file
- File naming format: `log_YYYY-MM-DD.txt`
- Example: `log_2026-02-27.txt`
- Automatic date detection ensures logs are properly separated

### 3. **Automatic Cleanup**

- Logs older than 10 days are automatically deleted
- Cleanup runs on application startup
- Prevents excessive storage usage
- Configurable retention period in code

### 4. **Cloudflare R2 Upload**

- Scheduled daily upload at 2:00 AM
- Uploads previous day's log file
- Uses AWS S3-compatible API with signature v4
- Automatic retry on failure
- Manual upload option in admin screen

## File Structure

### Log Directory

Logs are stored in the application's documents directory:

```
/data/data/com.example.msi_clock/documents/logs/
├── log_2026-02-17.txt  (will be deleted after 10 days)
├── log_2026-02-18.txt
├── ...
├── log_2026-02-26.txt
└── log_2026-02-27.txt  (current day)
```

### Log Entry Format

Each log entry follows this format:

```
[YYYY-MM-DD HH:mm:ss.SSS] [LEVEL] Message
```

Example entries:

```
[2026-02-27 14:30:45.123] [PUNCH] Recording punch for employee: 12345
[2026-02-27 14:30:45.234] [DEBUG] Camera capture completed in 110ms
[2026-02-27 14:30:45.567] [PUNCH] Punch successful for employee 12345 (checkin) - Total time: 444ms
[2026-02-27 14:30:50.890] [ERROR] Punch error for employee 99999: Connection timeout
```

## Configuration

### Admin Screen Settings

1. Navigate to Admin Settings (gear icon)
2. Scroll to "Logging Settings" section
3. Select log level:
   - **NORMAL**: Punch data only
   - **DEBUG**: All logging
4. Click "Save Settings" to apply changes

### R2 Configuration

To enable automatic log uploads, add R2 credentials to settings.json:

```json
{
  "r2": {
    "accountId": "your-cloudflare-account-id",
    "bucketName": "msi-clock-logs",
    "accessKeyId": "your-r2-access-key-id",
    "secretAccessKey": "your-r2-secret-access-key"
  }
}
```

**R2 Object Path Structure:**

```
logs/{deviceName}/log_YYYY-MM-DD.txt
```

Example:

```
logs/MSI-Tablet-01/log_2026-02-27.txt
logs/MSI-Tablet-02/log_2026-02-27.txt
```

## Usage

### Accessing Logs on Device

#### Method 1: Via ADB

```bash
# Pull all logs
adb pull /data/data/com.example.msi_clock/documents/logs/ ./logs/

# Pull specific log file
adb pull /data/data/com.example.msi_clock/documents/logs/log_2026-02-27.txt
```

#### Method 2: Via File Manager (Requires Root)

1. Install a root file manager
2. Navigate to `/data/data/com.example.msi_clock/documents/logs/`
3. Copy or view log files

### Manual Log Upload

1. Open Admin Settings
2. Scroll to "Logging Settings"
3. Click "Upload Yesterday's Logs Now"
4. Wait for confirmation message

### Viewing Logs in R2

1. Log into Cloudflare Dashboard
2. Navigate to R2 Storage
3. Open your bucket (e.g., `msi-clock-logs`)
4. Browse to `logs/{deviceName}/`
5. Download and view log files

## Log Levels Explained

### NORMAL Level Logs

**What's Logged:**

- Employee ID for each punch attempt
- Punch success/failure status
- Exception codes (1=shift not started, 2=not authorized, 3=shift finished)
- Punch type (check-in or check-out)
- Total processing time

**Example NORMAL Log:**

```
[2026-02-27 08:00:15.123] [PUNCH] Recording punch for employee: 12345
[2026-02-27 08:00:15.567] [PUNCH] Punch successful for employee 12345 (checkin) - Total time: 444ms
[2026-02-27 08:00:30.890] [PUNCH] Recording punch for employee: 67890
[2026-02-27 08:00:31.234] [PUNCH] Punch failed for employee 67890: Exception 2
```

### DEBUG Level Logs

**What's Logged (in addition to NORMAL):**

- Application initialization
- Camera initialization and errors
- SOAP service connection attempts
- Network connectivity status
- Performance timing for each operation
- Warnings and detailed error messages
- Log file management operations

**Example DEBUG Log:**

```
[2026-02-27 08:00:00.001] [INFO] Application starting...
[2026-02-27 08:00:00.123] [DEBUG] LoggerService initialized
[2026-02-27 08:00:00.234] [DEBUG] Next log upload scheduled for: 2026-02-28 02:00:00
[2026-02-27 08:00:15.123] [PUNCH] Recording punch for employee: 12345
[2026-02-27 08:00:15.150] [DEBUG] Punch service started at: 2026-02-27 08:00:15.123
[2026-02-27 08:00:15.200] [DEBUG] Capturing camera image...
[2026-02-27 08:00:15.310] [DEBUG] Camera capture completed in 110ms
[2026-02-27 08:00:15.320] [DEBUG] Calling SOAP service...
[2026-02-27 08:00:15.550] [DEBUG] SOAP service completed in 230ms
[2026-02-27 08:00:15.567] [PUNCH] Punch successful for employee 12345 (checkin) - Total time: 444ms
```

## Implementation Details

### Services

1. **LoggerService** (`lib/services/logger_service.dart`)
   - Singleton service for logging
   - Manages log files and rotation
   - Provides logging methods: `logPunch()`, `logDebug()`, `logInfo()`, `logWarning()`, `logError()`
   - Handles file I/O asynchronously

2. **LogUploadService** (`lib/services/log_upload_service.dart`)
   - Handles Cloudflare R2 uploads
   - Implements AWS Signature Version 4 authentication
   - Schedules daily uploads at 2 AM
   - Provides manual upload capability

3. **SettingsService** (`lib/services/settings_service.dart`)
   - Stores log level preference
   - Methods: `getLogLevel()`, `updateLogLevel()`

### Integration Points

Logging is integrated throughout the application:

- **main.dart**: Initializes logging services on app startup
- **punch_service.dart**: Logs all punch operations
- **admin_screen.dart**: Provides UI for log level selection and manual upload
- **soap_service.dart**: Can be extended to log SOAP operations
- **battery_monitor_service.dart**: Can be extended to log battery events

## Troubleshooting

### Logs Not Being Created

1. Check app permissions (storage access)
2. Verify log directory path in admin screen
3. Check DEBUG logs for initialization errors
4. Ensure sufficient storage space

### Logs Not Uploading to R2

1. Verify R2 credentials in settings.json
2. Check network connectivity
3. Review R2 bucket permissions
4. Use manual upload to test configuration
5. Check for error messages in logs

### Log Files Too Large

1. Switch to NORMAL log level
2. Reduce retention period (modify code)
3. Ensure automatic cleanup is working
4. Check for excessive error logging

### Cannot Access Logs

1. Use ADB to pull logs from device
2. Check file permissions
3. Verify log directory path
4. Enable USB debugging on device

## Best Practices

1. **Use NORMAL level in production** to minimize storage and performance impact
2. **Use DEBUG level for troubleshooting** specific issues
3. **Monitor R2 storage costs** if uploading many devices
4. **Review logs regularly** for patterns or issues
5. **Test R2 upload** after initial configuration
6. **Document device names** for easy log identification

## Performance Impact

### NORMAL Level

- Minimal impact (~1-2ms per punch)
- Small file sizes (~10-50KB per day per device)
- Recommended for production use

### DEBUG Level

- Moderate impact (~5-10ms per operation)
- Larger file sizes (~100-500KB per day per device)
- Use only when troubleshooting

## Security Considerations

1. **Logs contain employee IDs** - protect access to log files
2. **R2 credentials** - store securely, never commit to version control
3. **Log retention** - comply with data retention policies
4. **Access control** - restrict R2 bucket access to authorized users
5. **Encryption** - consider enabling R2 bucket encryption

## Future Enhancements

Potential improvements to consider:

1. Log compression before upload
2. Real-time log streaming
3. Log search and filtering in admin UI
4. Email alerts for critical errors
5. Log analytics dashboard
6. Configurable retention period in UI
7. Multiple log level granularity
8. Log export to CSV format

## Support

For issues or questions about the logging system:

1. Check this documentation
2. Review log files for error messages
3. Test with DEBUG level enabled
4. Contact development team with log samples
