# Battery Monitoring Admin Integration

This document describes how the battery monitoring feature is integrated into the Admin Screen of the MSI Clock Tablet application.

## Admin Screen Integration

The battery monitoring feature is fully integrated into the Admin Screen, allowing administrators to:

1. Configure device information
2. Manually trigger battery reports
3. Configure power saving settings
4. View device network information

## Device Information Section

Located at the top of the Admin Screen, this section allows administrators to:

- Set a custom device name that identifies the tablet in battery reports
- Specify the location where the tablet is installed
- View the device's MAC address
- Manually trigger a battery report to test the feature

### Device Name Field

The device name field allows administrators to set a custom name for the tablet. This name is:

- Used in all battery reports sent to the API
- Stored in the application settings
- Retrieved by the BatteryMonitorService when sending reports
- Defaulted to "MSI-Tablet" if not specified

### Location Field

The location field allows administrators to specify where the tablet is installed. This information is:

- Included in all battery reports
- Used in email alerts to help identify which tablet needs attention
- Stored in the application settings
- Defaulted to "Unknown" if not specified

### MAC Address Field

The MAC address field displays the device's unique hardware identifier. This information:

- Is retrieved using platform-specific code through method channels
- Helps identify the specific tablet in the network
- Is displayed as read-only in the Admin Screen
- Falls back to Android ID if the MAC address cannot be retrieved

### Manual Battery Report

The "Push Battery Data" button allows administrators to:

- Manually trigger a battery report for testing
- Verify that the API connection is working
- Confirm that the correct device information is being sent

## Power Saving Settings

The power saving settings allow administrators to configure:

- Inactivity threshold: How long the tablet must be inactive before sleep mode activates
- Heartbeat interval: How frequently the tablet checks in with the server

These settings help optimize battery life by:

- Reducing screen brightness during periods of inactivity
- Disabling the camera when not in use
- Minimizing network operations when the tablet is idle

## Implementation Details

### Device Name Storage

The device name is stored in the application settings using the SettingsService:

```dart
// In AdminScreen when saving settings
await _settings.updateBatterySettings(
  deviceName: _deviceNameController.text,
  location: _locationController.text,
);
```

### Device Name Retrieval

When sending battery reports, the BatteryMonitorService retrieves the device name:

```dart
// In BatteryMonitorService when reporting battery level
final deviceName = await _settingsService.getDeviceName();
final location = await _settingsService.getDeviceLocation();

// Create check-in data
final checkIn = BatteryCheckIn(
  deviceName: deviceName,
  location: location,
  batteryPct: batteryPct,
);
```

### Default Values

If no custom device name is set, the SettingsService provides a default:

```dart
// In SettingsService.getDeviceName()
if (settings.containsKey('battery') &&
    settings['battery'] is Map<String, dynamic> &&
    settings['battery']['deviceName'] is String) {
  return settings['battery']['deviceName'] as String;
}

return 'MSI-Tablet'; // Default value
```

### MAC Address Retrieval

The device's MAC address is retrieved using a method channel to communicate with native Android code:

```dart
// In AdminScreen._loadMacAddress()
try {
  // Call native method to get MAC address
  macAddress = await platform.invokeMethod('getMacAddress');
} catch (methodError) {
  print('Method channel error: $methodError');
  macAddress = 'Not available';
}
```

The native Android implementation in MainActivity.kt:

```kotlin
// Get device MAC address
private fun getMacAddress(): String {
  try {
    // Try to get MAC address from network interfaces
    val networkInterfaces = Collections.list(NetworkInterface.getNetworkInterfaces())
    for (networkInterface in networkInterfaces) {
      if (networkInterface.name.equals("wlan0", ignoreCase = true)) {
        val macBytes = networkInterface.hardwareAddress
        if (macBytes != null) {
          val macBuilder = StringBuilder()
          for (b in macBytes) {
            macBuilder.append(String.format("%02X:", b))
          }
          if (macBuilder.isNotEmpty()) {
            macBuilder.deleteCharAt(macBuilder.length - 1) // Remove last colon
            return macBuilder.toString()
          }
        }
      }
    }

    // Fallback to Android ID if MAC address is not available
    return Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
  } catch (e: Exception) {
    e.printStackTrace()
    return "Unknown"
  }
}
```

## User Interface

The device information section in the Admin Screen includes:

- Text fields for device name and location
- A read-only field displaying the device's MAC address
- A button to manually trigger a battery report
- Visual feedback during the battery reporting process

## Best Practices

When configuring device information:

1. Use descriptive device names that identify the specific tablet
2. Include the physical location where the tablet is installed
3. Test the configuration by manually triggering a battery report
4. Verify that the correct information appears in the monitoring system

## Troubleshooting

If battery reports are not being received:

1. Check that the device name and location are correctly set
2. Verify the API endpoint configuration
3. Use the "Push Battery Data" button to manually trigger a report
4. Check the application logs for any error messages
5. Ensure the tablet has network connectivity
