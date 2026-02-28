# Storage Issue Fix - Complete Solution

## Problem Identified

The application was filling up tablet storage over time, with files appearing as "System" files rather than app data. This made them invisible in the app's data/cache size and impossible to delete manually.

## Root Causes Identified

### 1. Camera Temporary Files (PRIMARY ISSUE - FIXED)
**Camera temporary files were not being cleaned up after each punch.**

### 2. Database Not Running Cleanup (SECONDARY ISSUE - FIXED)
**Database cleanup method existed but was never scheduled to run automatically.**

### Technical Details

In [`lib/services/punch_service.dart`](../lib/services/punch_service.dart), the camera capture process was:

```dart
final image = await _cameraController!.takePicture();
imageData = await image.readAsBytes();
```

**The Problem:**

- `takePicture()` creates a temporary `XFile` on disk in Android's system cache directory
- `readAsBytes()` reads the file content into memory
- **The temporary file was never deleted**
- Over hundreds/thousands of punches, these files accumulated as "System" storage

### Why Files Appeared as "System" Storage

Android's camera plugin stores temporary files in system-managed cache directories (typically `/data/user/0/com.example.msi_clock/cache/`). These files:

- Don't count toward the app's "Data" or "Cache" size in Android settings
- Appear as "System" storage instead
- Cannot be cleared through normal app data clearing
- Persist until manually deleted or the device runs out of space

## Solution Implemented

### Fix Applied to `lib/services/punch_service.dart`

Added immediate cleanup of temporary camera files after reading the image data:

```dart
Uint8List? imageData;
XFile? tempImageFile;
try {
  final cameraStartTime = DateTime.now();
  // Capture photo if camera is available and enabled
  if (isCameraEnabled &&
      _cameraController != null &&
      _cameraController!.value.isInitialized) {
    await _logger.logDebug('Capturing camera image...');
    tempImageFile = await _cameraController!.takePicture();
    imageData = await tempImageFile.readAsBytes();
    final cameraEndTime = DateTime.now();
    final cameraDuration = cameraEndTime.difference(cameraStartTime);
    await _logger.logDebug(
      'Camera capture completed in ${cameraDuration.inMilliseconds}ms',
    );

    // CRITICAL FIX: Delete the temporary camera file immediately after reading
    try {
      final file = File(tempImageFile.path);
      if (await file.exists()) {
        await file.delete();
        await _logger.logDebug('Deleted temporary camera file: ${tempImageFile.path}');
      }
    } catch (deleteError) {
      await _logger.logWarning('Failed to delete temporary camera file: $deleteError');
    }
  }
```

### Key Changes

1. **Store XFile reference**: Keep the `tempImageFile` reference instead of immediately discarding it
2. **Delete after reading**: Immediately delete the temporary file after `readAsBytes()`
3. **Error handling**: Wrap deletion in try-catch to prevent punch failures if deletion fails
4. **Logging**: Log successful deletions and any failures for monitoring

## Expected Results

### Immediate Benefits

- **No new temporary files accumulate** - Each camera file is deleted immediately after use
- **Storage stops growing** - No more orphaned files in system cache
- **Existing files remain** - This fix doesn't clean up old files (see below)

### Long-term Impact

- Tablets can run indefinitely without storage filling up
- "System" storage will remain stable
- App performance remains consistent

## Cleaning Up Existing Files

**Important:** This fix only prevents NEW files from accumulating. Existing orphaned files must be cleaned up manually.

### Manual Cleanup Options

1. **Clear App Cache** (Recommended):
   - Go to Android Settings → Apps → MSI Clock
   - Tap "Storage"
   - Tap "Clear Cache"
   - This removes all files in the app's cache directory

2. **Reinstall the App**:
   - Uninstall MSI Clock
   - Reinstall from the latest APK
   - This completely removes all app data and cache

3. **ADB Command** (For IT/Developers):
   ```bash
   adb shell rm -rf /data/user/0/com.example.msi_clock/cache/*
   ```

## Monitoring

The fix includes logging to help monitor the cleanup process:

- **Success**: `Deleted temporary camera file: /path/to/file.jpg`
- **Failure**: `Failed to delete temporary camera file: [error]`

Check logs in the admin panel to verify the fix is working correctly.

## Database Storage - Now Scheduled

### Fix Applied to `lib/services/punch_sync_service.dart`

Added automatic daily cleanup scheduling:

**Changes Made:**
1. Added `_cleanupTimer` field to track the cleanup timer
2. Added `_startDailyCleanup()` method that schedules cleanup at 3 AM daily
3. Calls `cleanupOldPunches()` on startup and then daily at 3 AM
4. Updated `dispose()` to cancel the cleanup timer

**Cleanup Behavior:**
- **Runs at:** 3 AM daily (same time as log uploads)
- **Retention period:** Configurable via settings (default: 30 days)
- **What it deletes:** All punch records (including image BLOBs) older than retention period
- **Initial cleanup:** Runs once on app startup, then daily

**Code Added:**
```dart
// Start daily cleanup timer (runs at 3 AM daily)
_startDailyCleanup();

// Perform initial cleanup on startup
await cleanupOldPunches();
```

The cleanup method reads the retention period from settings (`punchRetentionDays`, default 30 days) and deletes all punches older than that period, including their image data.

## Testing Recommendations

1. **Deploy the fix** to a test tablet
2. **Monitor storage** over 24-48 hours
3. **Check logs** for successful file deletions
4. **Verify** "System" storage is not increasing
5. **Clear existing cache** on production tablets before deploying

## Summary of All Fixes

### ✅ Camera Temporary Files (PRIMARY)
- **File:** [`lib/services/punch_service.dart`](../lib/services/punch_service.dart)
- **Fix:** Delete XFile immediately after reading image data
- **Impact:** Prevents 100-500KB per punch from accumulating as "System" files

### ✅ Database Cleanup Scheduling (SECONDARY)
- **File:** [`lib/services/punch_sync_service.dart`](../lib/services/punch_sync_service.dart)
- **Fix:** Schedule daily cleanup at 3 AM + run on startup
- **Impact:** Automatically removes old punch records and images based on retention policy

### ✅ Log File Rotation (ALREADY WORKING)
- **File:** [`lib/services/logger_service.dart`](../lib/services/logger_service.dart)
- **Status:** Already implemented, deletes logs older than 10 days

## Expected Storage Behavior After Fixes

1. **Camera files:** Zero accumulation - deleted immediately after each punch
2. **Database:** Grows for retention period (30 days default), then stabilizes
3. **Logs:** Grows for 10 days, then stabilizes
4. **Total storage:** Should remain stable indefinitely

## Related Files

- **Fixed**: [`lib/services/punch_service.dart`](../lib/services/punch_service.dart) - Camera file cleanup
- **Fixed**: [`lib/services/punch_sync_service.dart`](../lib/services/punch_sync_service.dart) - Database cleanup scheduling
- **Existing**: [`lib/services/logger_service.dart`](../lib/services/logger_service.dart) - Log file rotation (10 days)
- **Existing**: [`lib/services/punch_database_service.dart`](../lib/services/punch_database_service.dart) - Database cleanup implementation

## Date Implemented

2026-02-28
