import 'dart:convert';

/// Model class representing a battery check-in to be sent to the API
class BatteryCheckIn {
  /// The name of the device (tablet)
  final String deviceName;

  /// The location where the tablet is installed
  final String location;

  /// The battery percentage (0-100)
  final int batteryPct;

  /// The MAC address of the device (format: XX:XX:XX:XX:XX:XX)
  final String? macAddress;

  /// Free storage space in GB
  final double? freeSpaceGB;

  /// Total storage space in GB
  final double? totalSpaceGB;

  /// Free storage space percentage (0-100)
  final int? freeSpacePct;

  /// Creates a new BatteryCheckIn instance
  BatteryCheckIn({
    required this.deviceName,
    required this.location,
    required this.batteryPct,
    this.macAddress,
    this.freeSpaceGB,
    this.totalSpaceGB,
    this.freeSpacePct,
  });

  /// Converts the BatteryCheckIn to a JSON map
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {
      'device_name': deviceName,
      'location': location,
      'battery_pct': batteryPct,
    };
    // Only include MAC address if it's not null
    if (macAddress != null) {
      json['mac_address'] = macAddress!;
    }
    // Include storage metrics if available
    if (freeSpaceGB != null) {
      json['free_space_gb'] = freeSpaceGB!;
    }
    if (totalSpaceGB != null) {
      json['total_space_gb'] = totalSpaceGB!;
    }
    if (freeSpacePct != null) {
      json['free_space_pct'] = freeSpacePct!;
    }
    return json;
  }

  /// Converts the BatteryCheckIn to a JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Creates a BatteryCheckIn from a JSON map
  factory BatteryCheckIn.fromJson(Map<String, dynamic> json) {
    return BatteryCheckIn(
      deviceName: json['device_name'] as String,
      location: json['location'] as String,
      batteryPct: json['battery_pct'] as int,
      macAddress: json['mac_address'] as String?,
      freeSpaceGB: json['free_space_gb'] as double?,
      totalSpaceGB: json['total_space_gb'] as double?,
      freeSpacePct: json['free_space_pct'] as int?,
    );
  }
  @override
  String toString() =>
      'BatteryCheckIn(deviceName: $deviceName, location: $location, '
      'batteryPct: $batteryPct, macAddress: $macAddress, '
      'freeSpace: ${freeSpaceGB != null ? '${freeSpaceGB!.toStringAsFixed(2)} GB' : 'N/A'} / '
      '${totalSpaceGB != null ? '${totalSpaceGB!.toStringAsFixed(2)} GB' : 'N/A'}, '
      'freeSpacePct: ${freeSpacePct ?? 'N/A'}%)';
}
