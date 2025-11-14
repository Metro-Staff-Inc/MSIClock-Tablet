import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Info Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const NetworkInfoTestScreen(),
    );
  }
}

class NetworkInfoTestScreen extends StatefulWidget {
  const NetworkInfoTestScreen({super.key});

  @override
  State<NetworkInfoTestScreen> createState() => _NetworkInfoTestScreenState();
}

class _NetworkInfoTestScreenState extends State<NetworkInfoTestScreen> {
  final NetworkInfo _networkInfo = NetworkInfo();
  String _networkInfoText = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadNetworkInfo();
  }

  Future<void> _loadNetworkInfo() async {
    try {
      // Get all available methods from NetworkInfo
      final wifiName = await _networkInfo.getWifiName();
      final wifiBSSID = await _networkInfo.getWifiBSSID();
      final wifiIP = await _networkInfo.getWifiIP();
      final wifiIPv6 = await _networkInfo.getWifiIPv6();
      final wifiSubmask = await _networkInfo.getWifiSubmask();
      final wifiGatewayIP = await _networkInfo.getWifiGatewayIP();
      final wifiBroadcast = await _networkInfo.getWifiBroadcast();

      // Try to get MAC address if available
      String macAddress = "Not available";
      try {
        // Check if getMacAddress method exists
        final methods = _networkInfo.runtimeType.toString();
        macAddress = "Available methods: $methods";
      } catch (e) {
        macAddress = "Error getting methods: $e";
      }

      setState(() {
        _networkInfoText = '''
Network Info:
- WiFi Name: $wifiName
- WiFi BSSID: $wifiBSSID
- WiFi IP: $wifiIP
- WiFi IPv6: $wifiIPv6
- WiFi Submask: $wifiSubmask
- WiFi Gateway IP: $wifiGatewayIP
- WiFi Broadcast: $wifiBroadcast
- MAC Address: $macAddress
''';
      });
    } catch (e) {
      setState(() {
        _networkInfoText = 'Error getting network info: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Network Info Test')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_networkInfoText, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadNetworkInfo,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
