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
  /// Creates a new BatteryCheckIn instance
  BatteryCheckIn({
    required this.deviceName,
    required this.location,
    required this.batteryPct,
    this.macAddress,
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
    );
  }
  @override
  String toString() =>
      'BatteryCheckIn(deviceName: $deviceName, location: $location, batteryPct: $batteryPct, macAddress: $macAddress)';
}
