# Battery Monitoring Feature

This document describes the implementation of the battery monitoring feature in the MSI Clock Tablet application.

## Overview

The battery monitoring feature sends hourly reports of the tablet's battery level and MAC address to an API endpoint. This allows administrators to monitor the battery status of all tablets and receive alerts when battery levels are low, while also uniquely identifying each device by its MAC address.

## Components

### 1. BatteryCheckIn Model

Located in `lib/models/battery_check_in.dart`, this model represents the data sent to the API:

- `deviceName`: The name of the tablet (configurable in Admin Settings)
- `location`: The location where the tablet is installed (configurable in Admin Settings)
- `batteryPct`: The current battery percentage (0-100)
- `macAddress`: The device's MAC address in XX:XX:XX:XX:XX:XX format (retrieved from the device)

### 2. BatteryApiService

Located in `lib/services/battery_api_service.dart`, this service handles communication with the battery monitoring API:

- Sends battery check-in data to the API endpoint
- Handles network errors and retries failed requests
- Maintains a queue of pending requests for offline operation

### 3. BatteryMonitorService

Located in `lib/services/battery_monitor_service.dart`, this service:

- Initializes at app startup
- Schedules hourly battery reports
- Retrieves battery level using the battery_plus package
- Gets device information from SettingsService
- Supports manual triggering of reports for testing

### 4. Power Saving Features

Located in `lib/services/power_saving_manager.dart`, this component:

- Manages sleep mode to reduce battery consumption during inactivity
- Provides configurable inactivity threshold (default: 2 minutes)
- Optimizes network operations with configurable heartbeat intervals
- Properly dims the screen using the screen_brightness package
- Saves and restores screen brightness when entering/exiting sleep mode
- Disables camera during sleep mode to further reduce power consumption

### 5. Admin Screen Integration

The Admin Screen (`lib/screens/admin_screen.dart`) provides UI for:

- Setting device name and location
- Manually triggering battery reports for testing
- Configuring power saving settings
- Displaying device information including MAC address

## Configuration

All settings are stored using the SettingsService and can be configured in the Admin Screen:

- **Device Name**: Identifies the tablet in reports (default: "MSI-Tablet")
- **Location**: Describes where the tablet is installed (default: "Unknown")
- **API Endpoint**: The URL of the battery monitoring API (default: "https://battery-monitor-api.onrender.com")
- **Inactivity Threshold**: Time before sleep mode activates (default: 2 minutes)
- **SOAP Heartbeat Interval**: Time between SOAP connection checks (default: 30 seconds)

## API Integration

The application sends POST requests to the `/checkin` endpoint with the following JSON payload:

```json
{
  "device_name": "MSI-Tablet",
  "location": "Front Desk",
  "battery_pct": 75
}
```

The API responds with a success status and stores the data in a database. Low battery levels (below 50%) trigger email alerts to administrators.

## Sleep Mode UI

When the tablet is inactive for the configured threshold period:

1. The screen brightness is significantly reduced (to 5%) to minimize power consumption
2. The camera is disabled to save battery
3. A "SLEEP MODE" message is displayed with instructions to tap anywhere to wake
4. Network operations are reduced to conserve battery
5. Previous screen brightness is saved and restored when the device wakes up

## Error Handling

The battery monitoring feature includes robust error handling:

- Failed API requests are queued for later retry
- Network connectivity issues are handled gracefully
- Battery level retrieval errors default to 0% to ensure reporting continues
- All errors are logged for troubleshooting

## Testing

The feature has been thoroughly tested to ensure:

- Accurate battery level reporting
- Proper handling of network errors
- Correct device name and location in reports
- Effective power saving during inactivity
- Quick response when waking from sleep mode
