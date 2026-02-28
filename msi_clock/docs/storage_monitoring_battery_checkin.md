# Storage Monitoring in Battery Check-In

## Overview

Storage metrics have been added to the hourly battery check-in reports to proactively monitor tablet storage and identify devices that may be running low on space.

## Implementation

### Changes Made

#### 1. Added `disk_space` Package

**File:** [`pubspec.yaml`](../pubspec.yaml)

Added dependency:

```yaml
disk_space: ^0.2.1 # For getting device storage information
```

This package provides cross-platform access to device storage information.

#### 2. Updated Battery Check-In Model

**File:** [`lib/models/battery_check_in.dart`](../lib/models/battery_check_in.dart)

Added three new fields:

- `freeSpaceGB` - Free storage space in GB (double)
- `totalSpaceGB` - Total storage space in GB (double)
- `freeSpacePct` - Free storage percentage (0-100, integer)

These fields are optional and will be included in the API payload when available.

#### 3. Enhanced Battery Monitor Service

**File:** [`lib/services/battery_monitor_service.dart`](../lib/services/battery_monitor_service.dart)

Added `_getStorageMetrics()` method that:

- Uses `disk_space` package to get total and free disk space in MB
- Converts MB to GB (MB / 1024)
- Calculates free space percentage
- Includes error handling with fallback to null values
- Logs storage info along with battery percentage

## API Payload

The battery check-in now includes storage information:

```json
{
  "device_name": "Tablet-01",
  "location": "Main Entrance",
  "battery_pct": 85,
  "mac_address": "AA:BB:CC:DD:EE:FF",
  "free_space_gb": 5.0,
  "total_space_gb": 15.0,
  "free_space_pct": 33
}
```

**New Fields:**

- `free_space_gb` - Free storage in GB (double, e.g., 5.0 = 5GB)
- `total_space_gb` - Total storage in GB (double, e.g., 15.0 = 15GB)
- `free_space_pct` - Percentage of free space (integer, e.g., 33 = 33% free)

## Logging

Each battery check-in now logs storage information:

```
Battery check-in: Battery=85%, Free Storage=5.00GB / 15.00GB (33% free)
```

This helps with local monitoring and troubleshooting.

## Benefits

### Proactive Monitoring

- Identify tablets running low on storage before they fail
- Track storage trends over time
- Correlate storage issues with device problems

### Early Warning System

- Alert when storage drops below threshold (e.g., < 20%)
- Prevent storage-related app crashes
- Schedule maintenance before critical storage levels

### Historical Data

- Track storage consumption patterns
- Identify devices that need attention
- Validate that storage fixes are working

## Monitoring Recommendations

### Alert Thresholds

- **Warning:** < 20% free space (< 3GB on 16GB device)
- **Critical:** < 10% free space (< 1.5GB on 16GB device)
- **Emergency:** < 5% free space (< 750MB on 16GB device)

### Actions Based on Storage Levels

- **> 20%:** Normal operation
- **10-20%:** Schedule cleanup/maintenance
- **5-10%:** Immediate attention required
- **< 5%:** Critical - may cause app failures

## Testing

To manually trigger a battery report with storage metrics:

```dart
final batteryService = BatteryMonitorService();
await batteryService.triggerManualReport();
```

Check logs for output like:

```
Battery check-in: Battery=85%, Free Storage=5.00GB / 15.00GB (33% free)
```

## Related Files

- **Model:** [`lib/models/battery_check_in.dart`](../lib/models/battery_check_in.dart)
- **Service:** [`lib/services/battery_monitor_service.dart`](../lib/services/battery_monitor_service.dart)
- **API Service:** [`lib/services/battery_api_service.dart`](../lib/services/battery_api_service.dart)
- **Dependencies:** [`pubspec.yaml`](../pubspec.yaml)

## Date Implemented

2026-02-28
