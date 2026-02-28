# Log File Storage Location

## Current Location (Accessible)

Log files are now saved to an **easily accessible location** on the tablet:

```
/storage/emulated/0/Documents/MSIClock/logs/
```

### How to Access

**On the Tablet:**

1. Open any **File Manager** app (e.g., Files, My Files, File Manager)
2. Navigate to **Documents** folder
3. Open **MSIClock** folder
4. Open **logs** folder
5. View/copy any log file (format: `log_YYYY-MM-DD.txt`)

**Via USB Connection:**

1. Connect tablet to computer via USB
2. Enable **File Transfer** mode
3. Navigate to `Internal Storage > Documents > MSIClock > logs`
4. Copy log files to your computer

**Via ADB (Development):**

```bash
adb pull /storage/emulated/0/Documents/MSIClock/logs/
```

## File Format

- **Naming**: `{DeviceName}_YYYY-MM-DD.txt`
- **Example**: `MSI-Tablet_2026-02-28.txt`
- **Rotation**: New file created daily at midnight
- **Retention**: Files older than 10 days are automatically deleted
- **Device Name**: Taken from Admin Settings > Device Information > Device Name

## Log Levels

### NORMAL Mode (Default)

- Punch events only
- Errors
- Minimal logging for production

### DEBUG Mode

- All logging enabled
- Detailed debug information
- Network requests/responses
- State changes

Change log level in **Admin Settings > Logging Settings**

## Backup Methods

### 1. Cloudflare R2 (Automatic)

- **Schedule**: Daily at 2 AM
- **What**: Uploads yesterday's log file
- **Location**: `https://r2.cloudflarestorage.com/msi-tablet-logs/logs/{deviceName}/`
- **Manual**: Available in Admin Settings

### 2. Local Access (Manual)

- Use file manager to copy logs
- Share via email/messaging apps
- Transfer via USB

### 3. ADB Pull (Development)

```bash
# Pull all logs
adb pull /storage/emulated/0/Documents/MSIClock/logs/

# Pull specific date
adb pull /storage/emulated/0/Documents/MSIClock/logs/log_2026-02-28.txt
```

## Permissions

The app requests the following storage permissions:

- `WRITE_EXTERNAL_STORAGE` - To create log files
- `READ_EXTERNAL_STORAGE` - To read log files for upload
- `MANAGE_EXTERNAL_STORAGE` - For Android 11+ compatibility

These are automatically requested when the app first runs.

## Troubleshooting

### Logs Not Appearing in Documents Folder

**Cause**: Storage permission not granted

**Solution**:

1. Go to tablet **Settings > Apps > MSI Clock > Permissions**
2. Enable **Storage** permission
3. Restart the app

### Fallback Location

If external storage is unavailable, logs fall back to:

```
/data/data/com.example.msi_clock/app_flutter/logs/
```

(Not accessible without root - use R2 upload instead)

## Log Contents

Each log entry includes:

- **Timestamp**: `YYYY-MM-DD HH:mm:ss.SSS`
- **Level**: `[DEBUG]`, `[INFO]`, `[PUNCH]`, `[WARN]`, `[ERROR]`
- **Message**: Event description

### Example Log Entry:

```
[2026-02-28 14:30:45.123] [PUNCH] Employee 12345 punched IN
[2026-02-28 14:30:45.456] [INFO] Photo captured successfully
[2026-02-28 14:30:46.789] [DEBUG] SOAP request sent to server
```

## Related Documentation

- [`docs/r2_credentials_setup.md`](r2_credentials_setup.md) - R2 upload configuration
- [`docs/logging_system.md`](logging_system.md) - Complete logging system documentation
- [`docs/retrieve_android_logs.md`](retrieve_android_logs.md) - Log retrieval methods
