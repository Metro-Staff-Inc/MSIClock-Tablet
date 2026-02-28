import 'dart:typed_data';
class Punch {
  final String employeeId;
  final DateTime timestamp;
  final Uint8List? imageData;
  final bool isSynced;
  final String? firstName;
  final String? lastName;
  final String? punchType;
  final int? exception;
  final String? weeklyHours;
  const Punch({
    required this.employeeId,
    required this.timestamp,
    this.imageData,
    this.isSynced = false,
    this.firstName,
    this.lastName,
    this.punchType,
    this.exception,
    this.weeklyHours,
  });
  factory Punch.fromResponse(
    String employeeId,
    DateTime timestamp,
    Map<String, dynamic> response, {
    Uint8List? imageData,
  }) {
    return Punch(
      employeeId: employeeId,
      timestamp: timestamp,
      imageData: imageData,
      isSynced: !response['offline'],
      firstName: response['firstName'],
      lastName: response['lastName'],
      punchType: response['punchType'],
      exception: response['exception'],
      weeklyHours: response['weeklyHours'],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'employeeId': employeeId,
      'timestamp': timestamp.toIso8601String(),
      'isSynced': isSynced,
      'firstName': firstName,
      'lastName': lastName,
      'punchType': punchType,
      'exception': exception,
      'weeklyHours': weeklyHours,
    };
  }
  factory Punch.fromJson(Map<String, dynamic> json) {
    return Punch(
      employeeId: json['employeeId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isSynced: json['isSynced'] as bool,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      punchType: json['punchType'] as String?,
      exception: json['exception'] as int?,
      weeklyHours: json['weeklyHours'] as String?,
    );
  }
  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return 'Employee $employeeId';
  }
  bool get hasError => exception != null && exception! > 0;
  String getStatusMessage(String language) {
    if (!isSynced) {
      return language == 'en' ? 'Stored offline' : 'Almacenado sin conexión';
    }
    if (hasError) {
      switch (exception) {
        case 1:
          return language == 'en'
              ? 'Shift not yet started'
              : 'Turno no ha iniciado';
        case 2:
          return language == 'en' ? 'Not Authorized' : 'No Autorizado';
        case 3:
          return language == 'en'
              ? 'Shift has finished'
              : 'Turno ha finalizado';
        default:
          return language == 'en' ? 'Invalid ID' : 'ID Inválido';
      }
    }
    // Weekly hours are no longer displayed in the status message
    if (punchType?.toLowerCase() == 'checkin') {
      return language == 'en' ? 'Welcome!' : '¡Bienvenido!';
    } else {
      return language == 'en' ? 'Goodbye!' : '¡Adiós!';
    }
  }
}
