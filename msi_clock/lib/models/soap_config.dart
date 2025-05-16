class SoapConfig {
  final String endpoint;
  final List<String> fallbackEndpoints;
  final String username;
  final String password;
  final String clientId;
  final Duration timeout;

  // Track which endpoint is currently being used
  int _currentEndpointIndex = 0;

  // Getter for the current endpoint (primary or fallback)
  String get currentEndpoint =>
      _currentEndpointIndex == 0
          ? endpoint
          : fallbackEndpoints[_currentEndpointIndex - 1];

  // Method to switch to the next fallback endpoint
  // Returns true if switched successfully, false if no more fallbacks
  bool switchToNextEndpoint() {
    if (_currentEndpointIndex < fallbackEndpoints.length) {
      _currentEndpointIndex++;
      print(
        'ENDPOINT DEBUG: Switching to fallback endpoint: ${currentEndpoint}',
      );
      return true;
    }
    // Reset to primary endpoint if we've tried all fallbacks
    if (_currentEndpointIndex > 0) {
      _currentEndpointIndex = 0;
      print(
        'ENDPOINT DEBUG: Tried all fallbacks, resetting to primary endpoint',
      );
    }
    return false;
  }

  // Reset to the primary endpoint
  void resetToMainEndpoint() {
    _currentEndpointIndex = 0;
  }

  SoapConfig({
    required this.endpoint,
    this.fallbackEndpoints = const [],
    required this.username,
    required this.password,
    required this.clientId,
    this.timeout = const Duration(seconds: 10),
  });

  factory SoapConfig.fromJson(Map<String, dynamic> json) {
    List<String> fallbacks = [];
    if (json.containsKey('fallbackEndpoints') &&
        json['fallbackEndpoints'] is List) {
      fallbacks =
          (json['fallbackEndpoints'] as List).whereType<String>().toList();
    }

    return SoapConfig(
      endpoint: json['endpoint'] as String,
      fallbackEndpoints: fallbacks,
      username: json['username'] as String,
      password: json['password'] as String,
      clientId: json['clientId'] as String,
      timeout: Duration(seconds: json['timeout'] as int? ?? 10),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'fallbackEndpoints': fallbackEndpoints,
      'username': username,
      'password': password,
      'clientId': clientId,
      'timeout': timeout.inSeconds,
    };
  }
}
