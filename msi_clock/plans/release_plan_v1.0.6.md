# Release Plan - MSI Clock v1.0.6

**Release Date:** 2026-02-28  
**Previous Version:** 1.0.5+6  
**New Version:** 1.0.6+7  
**Release Type:** Minor Release (Bug Fixes + New Features)

---

## Executive Summary

Version 1.0.6 addresses critical storage issues that were causing tablets to run out of space over time, adds comprehensive logging capabilities for troubleshooting, and implements storage monitoring to proactively identify devices at risk. This release includes both critical bug fixes and important new features for better system observability.

---

## 🎯 Release Objectives

1. **Fix Critical Storage Issues** - Prevent tablets from running out of storage
2. **Improve Observability** - Add comprehensive logging for troubleshooting
3. **Proactive Monitoring** - Track storage metrics to identify issues early
4. **Enhance Maintainability** - Better tools for remote diagnostics

---

## 📋 Changes Since v1.0.5

### 🐛 Critical Bug Fixes

#### 1. **Camera Temporary File Cleanup** (HIGH PRIORITY)

- **Issue:** Camera temporary files were not being deleted after each punch, accumulating as "System" storage
- **Impact:** Tablets running out of storage after hundreds/thousands of punches
- **Fix:** Implemented immediate deletion of temporary camera files after image capture
- **File:** [`lib/services/punch_service.dart`](../lib/services/punch_service.dart)
- **Details:** See [`docs/storage_issue_fix.md`](../docs/storage_issue_fix.md)

**Technical Details:**

- Each punch creates a temporary `XFile` (~100-500KB)
- Files were stored in system cache directory
- Now deleted immediately after `readAsBytes()`
- Includes error handling to prevent punch failures

#### 2. **Database Cleanup Scheduling** (MEDIUM PRIORITY)

- **Issue:** Database cleanup method existed but was never scheduled to run
- **Impact:** Old punch records and images accumulated indefinitely
- **Fix:** Added automatic daily cleanup at 3 AM + cleanup on app startup
- **File:** [`lib/services/punch_sync_service.dart`](../lib/services/punch_sync_service.dart)
- **Details:** See [`docs/storage_issue_fix.md`](../docs/storage_issue_fix.md)

**Technical Details:**

- Cleanup runs daily at 3 AM
- Deletes punches older than retention period (default: 30 days)
- Includes image BLOBs in deletion
- Initial cleanup on app startup

---

### ✨ New Features

#### 1. **Comprehensive Logging System** (HIGH VALUE)

- **Purpose:** Enable remote troubleshooting and diagnostics
- **Features:**
  - Two log levels: NORMAL (punch data only) and DEBUG (all events)
  - Daily log rotation with automatic cleanup (10-day retention)
  - Cloudflare R2 upload at 2 AM daily
  - Manual upload option in Admin Screen
- **Files:**
  - [`lib/services/logger_service.dart`](../lib/services/logger_service.dart)
  - [`lib/services/log_upload_service.dart`](../lib/services/log_upload_service.dart)
- **Documentation:**
  - [`docs/logging_system.md`](../docs/logging_system.md)
  - [`docs/logging_system_summary.md`](../docs/logging_system_summary.md)
  - [`docs/log_file_location.md`](../docs/log_file_location.md)
  - [`docs/retrieve_android_logs.md`](../docs/retrieve_android_logs.md)

**Log Levels:**

- **NORMAL:** Punch events, successes, failures, exception codes
- **DEBUG:** All NORMAL logs + app lifecycle, camera, SOAP calls, performance metrics

**Log Format:**

```
[YYYY-MM-DD HH:mm:ss.SSS] [LEVEL] Message
```

**Storage Location:**

```
/data/data/com.example.msi_clock/documents/logs/log_YYYY-MM-DD.txt
```

**R2 Upload Path:**

```
logs/{deviceName}/log_YYYY-MM-DD.txt
```

#### 2. **R2 Credentials Configuration** (MEDIUM VALUE)

- **Purpose:** Secure storage of Cloudflare R2 credentials for log uploads
- **Implementation:** Gitignored credentials file with example template
- **Files:**
  - [`lib/config/r2_credentials.dart`](../lib/config/r2_credentials.dart) (gitignored)
  - [`lib/config/r2_credentials.dart.example`](../lib/config/r2_credentials.dart.example) (template)
- **Documentation:**
  - [`docs/r2_credentials_setup.md`](../docs/r2_credentials_setup.md)
  - [`docs/r2_credentials_implementation_summary.md`](../docs/r2_credentials_implementation_summary.md)

**Security Features:**

- Credentials never committed to Git
- AWS Signature Version 4 authentication
- Minimal permissions (read/write to specific bucket only)

#### 3. **Storage Monitoring in Battery Check-In** (HIGH VALUE)

- **Purpose:** Proactively monitor tablet storage levels
- **Features:**
  - Reports free space (GB), total space (GB), and free space percentage
  - Included in hourly battery check-in API calls
  - Logged locally for diagnostics
- **Files:**
  - [`lib/models/battery_check_in.dart`](../lib/models/battery_check_in.dart)
  - [`lib/services/battery_monitor_service.dart`](../lib/services/battery_monitor_service.dart)
- **Documentation:** [`docs/storage_monitoring_battery_checkin.md`](../docs/storage_monitoring_battery_checkin.md)

**New API Fields:**

```json
{
  "free_space_gb": 5.0,
  "total_space_gb": 15.0,
  "free_space_pct": 33
}
```

**Alert Thresholds (Recommended):**

- Warning: < 20% free space
- Critical: < 10% free space
- Emergency: < 5% free space

---

### 📦 New Dependencies

Added to [`pubspec.yaml`](../pubspec.yaml):

```yaml
crypto: ^3.0.3 # For HMAC-SHA256 signing (R2 uploads)
disk_space: ^0.2.1 # For getting device storage information
```

**Note:** These dependencies are already included in the current version.

---

## 🔄 Migration & Deployment

### Pre-Deployment Steps

1. **Clear Existing Cache on Tablets** (RECOMMENDED)
   - Go to Android Settings → Apps → MSI Clock
   - Tap "Storage" → "Clear Cache"
   - This removes accumulated temporary camera files from v1.0.5

2. **Configure R2 Credentials** (REQUIRED for log uploads)
   - Ensure [`lib/config/r2_credentials.dart`](../lib/config/r2_credentials.dart) exists with valid credentials
   - See [`docs/r2_credentials_setup.md`](../docs/r2_credentials_setup.md)

### Deployment Process

1. **Build Release APK**

   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

2. **Test on Physical Device**
   - Install APK on test tablet
   - Verify punch recording works
   - Check camera functionality
   - Verify logs are being created
   - Test manual log upload
   - Confirm storage metrics in battery check-in

3. **Deploy to Production Tablets**
   - Install APK on all tablets
   - Monitor logs for first 24-48 hours
   - Verify storage is not increasing

### Post-Deployment Monitoring

**First 24 Hours:**

- Monitor storage levels via battery check-in API
- Check that logs are being uploaded to R2
- Verify no new temporary files accumulating
- Review logs for any errors

**First Week:**

- Confirm database cleanup runs successfully
- Verify storage remains stable
- Check log file sizes are reasonable
- Monitor for any performance issues

---

## 📊 Expected Impact

### Storage Management

**Before v1.0.6:**

- Camera temp files: ~100-500KB per punch (never deleted)
- 100 punches/day = 10-50MB/day accumulation
- 30 days = 300MB-1.5GB of orphaned files
- Database: Grows indefinitely

**After v1.0.6:**

- Camera temp files: 0 accumulation (deleted immediately)
- Database: Stabilizes after retention period (30 days default)
- Logs: Stabilizes after 10 days
- **Total storage: Remains stable indefinitely**

### Observability

**Before v1.0.6:**

- No application logs
- Difficult to troubleshoot issues remotely
- No visibility into storage problems

**After v1.0.6:**

- Comprehensive logging with two levels
- Remote log access via R2
- Hourly storage monitoring
- Proactive issue detection

---

## 🧪 Testing Checklist

### Functional Testing

- [ ] App launches successfully
- [ ] Punch recording works (check-in/check-out)
- [ ] Camera captures images correctly
- [ ] Temporary camera files are deleted after punch
- [ ] Offline mode works
- [ ] Settings can be changed in Admin Screen
- [ ] Battery check-in includes storage metrics
- [ ] Logs are created in correct location
- [ ] Log level can be changed (NORMAL/DEBUG)
- [ ] Manual log upload works
- [ ] Database cleanup runs on startup
- [ ] No crashes or errors

### Storage Testing

- [ ] Verify camera temp files are deleted (check cache directory)
- [ ] Confirm storage is not increasing after multiple punches
- [ ] Check database size stabilizes after retention period
- [ ] Verify log files rotate daily
- [ ] Confirm old logs are deleted after 10 days

### Logging Testing

- [ ] NORMAL level logs punch events only
- [ ] DEBUG level logs all application events
- [ ] Log files rotate at midnight
- [ ] Logs upload to R2 at 2 AM
- [ ] Manual upload button works
- [ ] Log format is correct
- [ ] Device name appears in R2 path

### Monitoring Testing

- [ ] Battery check-in includes storage fields
- [ ] Storage metrics are accurate
- [ ] Free space percentage calculates correctly
- [ ] Storage info appears in logs

---

## 🚨 Known Issues & Limitations

### Existing Files Not Cleaned

**Issue:** This release only prevents NEW temporary files from accumulating. Existing orphaned files from v1.0.5 must be cleaned manually.

**Workaround:** Clear app cache before or after deploying v1.0.6:

- Android Settings → Apps → MSI Clock → Storage → Clear Cache

### R2 Upload Requires Configuration

**Issue:** Log uploads to R2 require valid credentials in [`lib/config/r2_credentials.dart`](../lib/config/r2_credentials.dart).

**Workaround:**

- Copy [`lib/config/r2_credentials.dart.example`](../lib/config/r2_credentials.dart.example) to `r2_credentials.dart`
- Fill in actual Cloudflare R2 credentials
- Rebuild APK

### Log Files Contain Employee IDs

**Security Consideration:** Log files contain employee IDs for punch events. Ensure R2 bucket access is restricted to authorized personnel only.

---

## 📝 CHANGELOG Entry

```markdown
## [1.0.6] - 2026-02-28

### Fixed

- **CRITICAL:** Fixed camera temporary files not being deleted after each punch, preventing storage accumulation
- Fixed database cleanup not running automatically - now scheduled daily at 3 AM
- Improved storage management to prevent tablets from running out of space

### Added

- Comprehensive logging system with two levels (NORMAL and DEBUG)
- Daily log rotation with automatic cleanup (10-day retention)
- Cloudflare R2 log upload at 2 AM daily with manual upload option
- Storage monitoring in hourly battery check-in (free space, total space, percentage)
- R2 credentials configuration with secure gitignored file
- Admin screen controls for log level selection and manual upload
- Detailed documentation for logging system and storage fixes

### Changed

- Enhanced battery check-in API to include storage metrics
- Updated punch service to immediately delete temporary camera files
- Modified punch sync service to schedule automatic database cleanup
- Added crypto package for R2 authentication (HMAC-SHA256)
- Added disk_space package for storage monitoring
```

---

## 🔗 Related Documentation

### New Documentation Files

- [`docs/logging_system.md`](../docs/logging_system.md) - Complete logging system documentation
- [`docs/logging_system_summary.md`](../docs/logging_system_summary.md) - Quick reference
- [`docs/log_file_location.md`](../docs/log_file_location.md) - Log storage locations
- [`docs/retrieve_android_logs.md`](../docs/retrieve_android_logs.md) - How to access logs
- [`docs/storage_issue_fix.md`](../docs/storage_issue_fix.md) - Storage fix details
- [`docs/storage_monitoring_battery_checkin.md`](../docs/storage_monitoring_battery_checkin.md) - Storage monitoring
- [`docs/r2_credentials_setup.md`](../docs/r2_credentials_setup.md) - R2 configuration guide
- [`docs/r2_credentials_implementation_summary.md`](../docs/r2_credentials_implementation_summary.md) - R2 summary

### Existing Documentation

- [`docs/release_process.md`](../docs/release_process.md) - Standard release process
- [`docs/battery_monitoring_feature.md`](../docs/battery_monitoring_feature.md) - Battery monitoring
- [`docs/offline_punch_system.md`](../docs/offline_punch_system.md) - Offline functionality

---

## 👥 Stakeholder Communication

### IT Team

- **Action Required:** Clear app cache on all tablets before or after deployment
- **Monitoring:** Watch storage levels via battery check-in API
- **Access:** Ensure R2 bucket access for log retrieval

### Development Team

- **Action Required:** Configure R2 credentials before building release APK
- **Testing:** Verify all fixes on test device before production deployment
- **Documentation:** Review new documentation files

### Management

- **Impact:** Resolves critical storage issue preventing tablet failures
- **Benefits:** Better troubleshooting capabilities with comprehensive logging
- **Monitoring:** Proactive storage alerts to prevent future issues

---

## 🎯 Success Criteria

### Immediate (24 hours)

- ✅ All tablets successfully updated to v1.0.6
- ✅ No increase in "System" storage on tablets
- ✅ Logs being created and uploaded to R2
- ✅ Storage metrics appearing in battery check-in

### Short-term (1 week)

- ✅ Storage levels remain stable across all tablets
- ✅ Database cleanup runs successfully
- ✅ No performance degradation
- ✅ Logs provide useful troubleshooting information

### Long-term (1 month)

- ✅ Zero tablets running out of storage
- ✅ Consistent log uploads for all devices
- ✅ Proactive identification of storage issues
- ✅ Reduced support tickets related to storage

---

## 📞 Support & Escalation

### Issues During Deployment

1. Check logs in Admin Screen or via ADB
2. Verify R2 credentials are configured correctly
3. Confirm network connectivity for log uploads
4. Review [`docs/storage_issue_fix.md`](../docs/storage_issue_fix.md) for troubleshooting

### Post-Deployment Issues

1. Monitor storage levels via battery check-in API
2. Review uploaded logs in R2 bucket
3. Check for error messages in DEBUG logs
4. Contact development team with log samples

---

## ✅ Release Approval

**Prepared by:** Development Team  
**Date:** 2026-02-28  
**Status:** Ready for Review

**Approvals Required:**

- [ ] Technical Lead - Code review and testing
- [ ] IT Manager - Deployment strategy
- [ ] Project Manager - Release timing

---

## 📅 Release Timeline

1. **Review & Approval** - Review this release plan
2. **Version Update** - Update [`pubspec.yaml`](../pubspec.yaml) to 1.0.6+7
3. **CHANGELOG Update** - Update [`CHANGELOG.md`](../CHANGELOG.md)
4. **Build** - Create release APK
5. **Testing** - Test on physical device
6. **Deployment** - Roll out to production tablets
7. **Monitoring** - Monitor for 24-48 hours post-deployment

---

## 🔐 Security Considerations

1. **R2 Credentials** - Never commit to Git, use gitignored file
2. **Log Data** - Contains employee IDs, restrict R2 bucket access
3. **API Keys** - Rotate R2 credentials periodically
4. **Access Control** - Limit who can access logs and storage data

---

## 📈 Metrics to Track

### Storage Metrics

- Free space percentage per device
- Total storage used by app
- Database size over time
- Log file sizes

### Operational Metrics

- Log upload success rate
- Database cleanup execution
- Camera file deletion success rate
- Battery check-in reliability

### Performance Metrics

- Punch processing time
- Log write performance
- Storage query performance
- App startup time

---

## 🎉 Conclusion

Version 1.0.6 represents a significant improvement in system reliability and observability. The critical storage fixes prevent tablets from running out of space, while the new logging system provides essential tools for remote troubleshooting and proactive monitoring.

**Key Benefits:**

- ✅ Prevents storage exhaustion on tablets
- ✅ Enables remote diagnostics and troubleshooting
- ✅ Provides proactive storage monitoring
- ✅ Improves long-term system maintainability

**Recommendation:** Deploy to production as soon as testing is complete.
