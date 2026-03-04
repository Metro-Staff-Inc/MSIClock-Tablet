import 'dart:convert';

/// Model class representing a telemetry check-in to be sent to the API
/// Updated to match the new telemetry API specification
class BatteryCheckIn {
  /// The MAC address of the device (format: XX:XX:XX:XX:XX:XX) - REQUIRED
  final String macAddress;

  /// The name of the device (tablet)
  final String? deviceName;

  /// The location where the tablet is installed
  final String? location;

  /// Timestamp when telemetry was collected (UTC) - REQUIRED
  final DateTime reportedAt;

  /// The battery percentage (0-100)
  final int? batteryPct;

  /// Free storage space in bytes
  final int? freeSpace;

  /// Total storage space in bytes
  final int? totalSpace;

  /// App version (e.g., "1.0.5+6")
  final String? appVersion;

  /// Creates a new BatteryCheckIn instance
  BatteryCheckIn({
    required this.macAddress,
    required this.reportedAt,
    this.deviceName,
    this.location,
    this.batteryPct,
    this.freeSpace,
    this.totalSpace,
    this.appVersion,
  }) {
    // Validate MAC address format
    if (!isValidMacAddress(macAddress)) {
      throw ArgumentError('Invalid MAC address format: $macAddress');
    }
    // Validate battery percentage
    if (batteryPct != null && (batteryPct! < 0 || batteryPct! > 100)) {
      throw ArgumentError('Battery percentage must be between 0 and 100');
    }
    // Validate storage values
    if (freeSpace != null && freeSpace! < 0) {
      throw ArgumentError('Free space must be positive');
    }
    if (totalSpace != null && totalSpace! < 0) {
      throw ArgumentError('Total space must be positive');
    }
  }

  /// Validates MAC address format (XX:XX:XX:XX:XX:XX or XX-XX-XX-XX-XX-XX)
  static bool isValidMacAddress(String mac) {
    final regex = RegExp(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$');
    return regex.hasMatch(mac);
  }

  /// Converts the BatteryCheckIn to a JSON map matching the new API schema
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'mac_address': macAddress,
      'reported_at': reportedAt.toUtc().toIso8601String(),
    };

    // Include optional fields if available
    if (deviceName != null && deviceName!.isNotEmpty) {
      json['device_name'] = deviceName!;
    }
    if (location != null && location!.isNotEmpty) {
      json['location'] = location!;
    }
    if (batteryPct != null) {
      json['battery_pct'] = batteryPct!;
    }
    if (freeSpace != null) {
      json['free_space'] = freeSpace!;
    }
    if (totalSpace != null) {
      json['total_space'] = totalSpace!;
    }
    if (appVersion != null && appVersion!.isNotEmpty) {
      json['app_version'] = appVersion!;
    }

    return json;
  }

  /// Converts the BatteryCheckIn to a JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Creates a BatteryCheckIn from a JSON map
  factory BatteryCheckIn.fromJson(Map<String, dynamic> json) {
    return BatteryCheckIn(
      macAddress: json['mac_address'] as String,
      reportedAt: DateTime.parse(json['reported_at'] as String),
      deviceName: json['device_name'] as String?,
      location: json['location'] as String?,
      batteryPct: json['battery_pct'] as int?,
      freeSpace: json['free_space'] as int?,
      totalSpace: json['total_space'] as int?,
      appVersion: json['app_version'] as String?,
    );
  }

  @override
  String toString() {
    final freeSpaceGB =
        freeSpace != null
            ? (freeSpace! / (1024 * 1024 * 1024)).toStringAsFixed(2)
            : 'N/A';
    final totalSpaceGB =
        totalSpace != null
            ? (totalSpace! / (1024 * 1024 * 1024)).toStringAsFixed(2)
            : 'N/A';
    final freeSpacePct =
        (freeSpace != null && totalSpace != null && totalSpace! > 0)
            ? ((freeSpace! / totalSpace!) * 100).toStringAsFixed(1)
            : 'N/A';

    return 'BatteryCheckIn(macAddress: $macAddress, '
        'deviceName: ${deviceName ?? 'N/A'}, location: ${location ?? 'N/A'}, '
        'reportedAt: ${reportedAt.toIso8601String()}, '
        'batteryPct: ${batteryPct ?? 'N/A'}%, '
        'freeSpace: ${freeSpaceGB}GB / ${totalSpaceGB}GB ($freeSpacePct% free), '
        'appVersion: ${appVersion ?? 'N/A'})';
  }
}
