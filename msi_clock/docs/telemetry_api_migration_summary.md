# Telemetry API Migration Summary

## Overview

The MSI Clock Tablet application has been successfully updated to integrate with the new unified telemetry API. This document summarizes the changes made and provides guidance for deployment and testing.

**Migration Date:** 2026-03-04  
**Related Documentation:** [`docs/TABLET-INTEGRATION.md`](TABLET-INTEGRATION.md:1)

---

## Changes Implemented

### 1. Model Updates - [`lib/models/battery_check_in.dart`](../lib/models/battery_check_in.dart:1)

**Breaking Changes:**

- `macAddress` is now **required** (was optional)
- `reportedAt` is now **required** (new field - UTC timestamp)
- Storage fields changed from GB (double) to bytes (int):
  - `freeSpaceGB` → `freeSpace` (bytes)
  - `totalSpaceGB` → `totalSpace` (bytes)
- Removed `freeSpacePct` (server now calculates this)
- `deviceName` and `location` are now optional (were required)

**New Features:**

- Added MAC address format validation
- Added battery percentage validation (0-100)
- Added storage value validation (positive integers)
- Improved error messages with ArgumentError

### 2. Service Updates

#### [`lib/services/battery_monitor_service.dart`](../lib/services/battery_monitor_service.dart:1)

**Changes:**

- Added UTC timestamp generation for each telemetry report
- Updated storage metrics to return both bytes (for API) and GB (for logging)
- Added MAC address validation before sending telemetry
- Enhanced logging with MAC address information
- Updated error handling with better retry logic

**Storage Conversion:**

```dart
// MB to bytes: MB * 1024 * 1024
freeSpaceBytes = (freeSpaceMB * 1024 * 1024).toInt()
```

#### [`lib/services/battery_api_service.dart`](../lib/services/battery_api_service.dart:1)

**Changes:**

- Updated endpoint from `/checkin` to `/api/telemetry`
- Added Bearer token authentication
- Increased timeout from 10s to 30s
- Enhanced error handling:
  - **401 Unauthorized:** Logs auth error, doesn't retry
  - **400 Bad Request:** Logs validation errors with details, doesn't retry
  - **5xx Server Errors:** Logs warning, adds to retry queue
  - **Network Errors:** Logs warning, adds to retry queue
- Added response parsing to extract `device_id` from success responses
- Improved logging throughout the request lifecycle

#### [`lib/services/settings_service.dart`](../lib/services/settings_service.dart:1)

**Changes:**

- Updated default API endpoint: `https://admin.msistaff.com`
- Added API token field with default: `a49755e6-4445-4731-b349-60fd1e41b88f`
- Added `getBatteryApiToken()` method
- Updated `updateBatterySettings()` to include `apiToken` parameter
- Updated default settings structure to include token

### 3. UI Updates - [`lib/screens/admin_screen.dart`](../lib/screens/admin_screen.dart:1)

**Changes:**

- Added "Telemetry API Token" input field (obscured text)
- Updated "Battery API Endpoint" label to "Telemetry API Endpoint"
- Updated default endpoint hint text
- Added token controller initialization and disposal
- Updated settings load/save logic to include token

### 4. Test Updates - [`test/battery_monitor_test.dart`](../test/battery_monitor_test.dart:1)

**Changes:**

- Updated test cases to include required `macAddress` and `reportedAt` fields
- Updated assertions to check for new field names (`free_space`, `total_space`)
- Added validation for timestamp field in JSON

---

## Configuration Changes

### Old Configuration

```json
{
  "battery": {
    "apiEndpoint": "https://battery-monitor-api.onrender.com",
    "deviceName": "MSI-Tablet",
    "location": "Unknown"
  }
}
```

### New Configuration

```json
{
  "battery": {
    "apiEndpoint": "https://admin.msistaff.com",
    "apiToken": "a49755e6-4445-4731-b349-60fd1e41b88f",
    "deviceName": "MSI-Tablet",
    "location": "Unknown"
  }
}
```

**Migration Notes:**

- Existing settings will be automatically migrated on first app launch
- The new token will be added with the default value
- The endpoint will remain as configured (manual update recommended)

---

## API Request Format

### Old Format

```json
{
  "device_name": "MSI-Tablet",
  "location": "Main Office",
  "battery_pct": 85,
  "mac_address": "AA:BB:CC:DD:EE:FF",
  "free_space_gb": 5.0,
  "total_space_gb": 15.0,
  "free_space_pct": 33,
  "app_version": "1.0.5+6"
}
```

### New Format

```json
{
  "mac_address": "AA:BB:CC:DD:EE:FF",
  "device_name": "MSI-Tablet",
  "location": "Main Office",
  "reported_at": "2026-03-04T01:00:00.000Z",
  "battery_pct": 85,
  "free_space": 5368709120,
  "total_space": 16106127360,
  "app_version": "1.0.5+6"
}
```

**Key Differences:**

- `mac_address` is now first and required
- `reported_at` timestamp is required (ISO-8601 UTC)
- Storage in bytes instead of GB
- No `free_space_pct` (server calculates)
- Authorization header required: `Bearer a49755e6-4445-4731-b349-60fd1e41b88f`

---

## Deployment Instructions

### 1. Pre-Deployment Checklist

- [ ] Review all code changes
- [ ] Verify new API endpoint is accessible
- [ ] Confirm API token is correct
- [ ] Test on development device
- [ ] Backup current settings

### 2. Deployment Steps

1. **Build the updated APK:**

   ```bash
   flutter build apk --release
   ```

2. **Test on a single device first:**
   - Install the new APK
   - Open Admin Settings
   - Verify endpoint shows: `https://admin.msistaff.com`
   - Verify token field is present (obscured)
   - Click "Push Battery Data" to test
   - Check logs for successful telemetry send

3. **Verify in dashboard:**
   - Check that device appears in new admin dashboard
   - Verify all telemetry fields are populated correctly
   - Confirm storage values are in bytes and calculated correctly

4. **Roll out to all devices:**
   - Deploy via AnyDesk or physical access
   - Monitor first few telemetry reports from each device

### 3. Post-Deployment Verification

- [ ] All devices appear in new dashboard
- [ ] Telemetry data is being received hourly
- [ ] Storage values are accurate
- [ ] Battery percentages are correct
- [ ] MAC addresses are properly formatted
- [ ] Timestamps are in UTC
- [ ] No authentication errors in logs

---

## Testing Guide

### Manual Testing

1. **Test Telemetry Submission:**
   - Open Admin Settings (password required)
   - Scroll to Device Information section
   - Click "Push Battery Data"
   - Verify success message
   - Check logs for confirmation

2. **Test Configuration:**
   - Update API endpoint (if needed)
   - Update API token (if needed)
   - Save settings
   - Restart app
   - Verify settings persisted

3. **Test Error Handling:**
   - Try invalid token → Should log 401 error
   - Try invalid endpoint → Should log network error
   - Verify retry queue works

### Log Monitoring

Look for these log entries:

**Success:**

```
Telemetry check-in: Battery=85%, Free Storage=5.00GB / 15.00GB (33% free), MAC=AA:BB:CC:DD:EE:FF
Telemetry sent successfully. Device ID: 550e8400-e29b-41d4-a716-446655440000
```

**Errors:**

```
Telemetry authentication failed (401). Check API token in settings.
Telemetry validation failed (400): Invalid MAC address format
Telemetry server error (500). Will retry.
Telemetry network error: SocketException. Will retry.
```

---

## Troubleshooting

### Issue: "Cannot send telemetry: MAC address is not available"

**Cause:** Device MAC address could not be retrieved  
**Solution:**

1. Check Android permissions
2. Verify network interface is active
3. Check [`MainActivity.kt`](../android/app/src/main/kotlin/com/example/msi_clock/MainActivity.kt:179) MAC address retrieval logic

### Issue: "Telemetry authentication failed (401)"

**Cause:** Invalid or missing API token  
**Solution:**

1. Open Admin Settings
2. Verify token matches: `a49755e6-4445-4731-b349-60fd1e41b88f`
3. Save settings and retry

### Issue: "Telemetry validation failed (400)"

**Cause:** Invalid data format  
**Solution:**

1. Check logs for specific validation error
2. Common issues:
   - Invalid MAC address format
   - Invalid timestamp format
   - Battery percentage out of range (0-100)
   - Negative storage values

### Issue: Storage values seem incorrect

**Cause:** Conversion error or disk space API issue  
**Solution:**

1. Check logs for storage metrics
2. Verify conversion: bytes = MB _ 1024 _ 1024
3. Compare with device storage settings

---

## Rollback Procedure

If issues are encountered:

1. **Quick Fix - Change Endpoint:**
   - Open Admin Settings
   - Change endpoint back to old API (if still available)
   - Save settings

2. **Full Rollback:**
   - Uninstall current version
   - Reinstall previous APK version
   - Reconfigure settings

3. **Data Considerations:**
   - Settings file will be preserved
   - May need to manually update endpoint back to old value
   - Telemetry data in new dashboard will remain

---

## Security Considerations

### API Token Storage

- Token is stored in plain text in settings.json
- File is in app's private directory (not accessible to other apps)
- Token is shared across all tablets (single key authentication)
- Token is obscured in UI but not encrypted

**Recommendations:**

- Keep token confidential
- Rotate token periodically if compromised
- Monitor API access logs for unauthorized usage

### Network Security

- Production API uses HTTPS (TLS 1.2+)
- Certificate validation is enabled
- No sensitive user data is transmitted
- MAC addresses are not considered PII

---

## Performance Impact

### Network Usage

- **Frequency:** Once per hour
- **Payload Size:** ~200-300 bytes per request
- **Bandwidth:** Negligible (~7KB per day per device)

### Battery Impact

- Minimal - single HTTP request per hour
- No background services added
- Existing hourly schedule maintained

### Storage Impact

- No additional storage required
- Settings file size increased by ~50 bytes (token field)

---

## Future Enhancements

### Potential Improvements

1. **Token Encryption:**
   - Encrypt API token in settings file
   - Use Android Keystore for secure storage

2. **Retry Strategy:**
   - Implement exponential backoff (currently fixed 5-minute retry)
   - Add maximum retry attempts limit

3. **Offline Queue:**
   - Persist failed requests to disk
   - Send queued requests when connectivity restored

4. **Device ID Caching:**
   - Cache device_id from API response
   - Use for future requests (if API supports it)

5. **Telemetry Metrics:**
   - Track success/failure rates
   - Monitor API response times
   - Alert on repeated failures

---

## Related Files

### Modified Files

- [`lib/models/battery_check_in.dart`](../lib/models/battery_check_in.dart:1) - Model with new schema
- [`lib/services/battery_monitor_service.dart`](../lib/services/battery_monitor_service.dart:1) - Telemetry collection
- [`lib/services/battery_api_service.dart`](../lib/services/battery_api_service.dart:1) - API communication
- [`lib/services/settings_service.dart`](../lib/services/settings_service.dart:1) - Configuration management
- [`lib/screens/admin_screen.dart`](../lib/screens/admin_screen.dart:1) - Admin UI
- [`test/battery_monitor_test.dart`](../test/battery_monitor_test.dart:1) - Unit tests

### Documentation

- [`docs/TABLET-INTEGRATION.md`](TABLET-INTEGRATION.md:1) - API specification
- [`plans/telemetry_api_migration_plan.md`](../plans/telemetry_api_migration_plan.md:1) - Migration plan
- [`docs/storage_monitoring_battery_checkin.md`](storage_monitoring_battery_checkin.md:1) - Old documentation (needs update)

---

## Support

For issues or questions:

1. Check logs in Admin Settings → View Logs
2. Review this documentation
3. Check API specification in [`TABLET-INTEGRATION.md`](TABLET-INTEGRATION.md:1)
4. Contact MSI Admin development team

---

**Document Version:** 1.0  
**Last Updated:** 2026-03-04  
**Author:** Development Team
