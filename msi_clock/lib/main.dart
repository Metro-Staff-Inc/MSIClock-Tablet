import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'providers/punch_provider.dart';
import 'screens/admin_screen.dart';
import 'widgets/admin_password_dialog.dart';
import 'services/update_service.dart';

// Method channel for native communication
const platform = MethodChannel('com.example.msi_clock/kiosk');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations to landscape
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Enable kiosk mode (fullscreen, no system UI)
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  // Prevent the app from being closed with back button
  SystemChannels.platform.invokeMethod('SystemNavigator.preventPopOnBackPress');

  // Keep the screen on at all times
  WakelockPlus.enable();

  // Initialize automatic update scheduler
  final updateService = UpdateService();
  await updateService.scheduleUpdateCheck();
  print('Automatic update scheduler initialized - will check at 1:00 AM daily');

  // Initialize SOAP configuration
  final soapConfig = await AppConfig.getSoapConfig();

  runApp(
    ChangeNotifierProvider(
      create: (_) => PunchProvider(soapConfig),
      child: const MSIClockApp(),
    ),
  );
}

class MSIClockApp extends StatelessWidget {
  const MSIClockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSI Clock',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const InitializationScreen(),
    );
  }
}

// Screen to handle initialization of connections before showing the main clock screen
class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  bool _isInitializing = true;
  String _statusMessage = 'Initializing...';
  int _retryCount = 0;
  final int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    // Start initialization process
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final provider = context.read<PunchProvider>();

    setState(() {
      _statusMessage = 'Checking server connection...';
    });

    // Try to establish SOAP connection with retries
    bool isConnected = false;
    for (int i = 0; i < _maxRetries; i++) {
      _retryCount = i;
      try {
        // Force a new connection attempt each time
        isConnected = await provider.checkConnectivity(forceReconnect: true);
        if (isConnected) {
          print('SOAP connection established on attempt ${i + 1}');
          break;
        } else {
          setState(() {
            _statusMessage =
                'Retrying server connection (${i + 1}/$_maxRetries)...';
          });
          // Wait before retry
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        print('Error checking connectivity: $e');
        if (i < _maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    // Even if connection failed after retries, continue to camera initialization
    setState(() {
      _statusMessage = 'Initializing camera...';
    });

    // Try to initialize camera with retries
    bool isCameraInitialized = false;
    for (int i = 0; i < _maxRetries; i++) {
      try {
        await provider.initializeCamera(forceReinit: true);
        if (provider.isCameraInitialized) {
          isCameraInitialized = true;
          print('Camera initialized on attempt ${i + 1}');
          break;
        } else {
          setState(() {
            _statusMessage =
                'Retrying camera initialization (${i + 1}/$_maxRetries)...';
          });
          // Wait before retry
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        print('Error initializing camera: $e');
        if (i < _maxRetries - 1) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    // Proceed to main screen regardless of initialization results
    // The main screen will handle offline mode if needed
    setState(() {
      _isInitializing = false;
    });

    // Navigate to the main clock screen
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ClockScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: AppTheme.windowBackground),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // MSI Logo
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Image.asset('assets/images/msi_logo.png', height: 150),
              ),
              const SizedBox(height: 32),
              // Loading indicator
              const CircularProgressIndicator(
                color: AppTheme.mainGreen,
                strokeWidth: 5,
              ),
              const SizedBox(height: 24),
              // Status message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  _statusMessage,
                  style: const TextStyle(
                    fontSize: 24,
                    color: AppTheme.defaultText,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ClockScreen extends StatefulWidget {
  const ClockScreen({super.key});

  @override
  State<ClockScreen> createState() => _ClockScreenState();
}

class _ClockScreenState extends State<ClockScreen> with WidgetsBindingObserver {
  final TextEditingController _idController = TextEditingController();
  bool _isKeypadDisabled = false;
  Timer? _statusMessageTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize camera and check connectivity when screen loads
    Future.microtask(() async {
      final provider = context.read<PunchProvider>();
      // Check connectivity first to update online status
      await provider.checkConnectivity();
      // Then initialize camera
      await provider.initializeCamera();
    });
  }

  @override
  void dispose() {
    _idController.dispose();
    _statusMessageTimer?.cancel();
    context.read<PunchProvider>().disposeCamera();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Check connectivity when app is resumed from background
      if (mounted) {
        context.read<PunchProvider>().checkConnectivity();
      }
    }
  }

  Future<void> _handlePunch() async {
    final employeeId = _idController.text;
    if (employeeId.isEmpty) return;

    // Debug: Log start time
    final startTime = DateTime.now();
    print('TIMING: Punch initiated at ${startTime.toIso8601String()}');

    // Disable keypad
    setState(() {
      _isKeypadDisabled = true;
    });

    // Cancel any existing timer
    _statusMessageTimer?.cancel();

    // Record the punch and await the SOAP response
    _idController.clear();
    print(
      'TIMING: Calling recordPunch() at ${DateTime.now().toIso8601String()}',
    );
    await context.read<PunchProvider>().recordPunch(employeeId);

    // Debug: Log SOAP response received time and calculate duration
    final responseTime = DateTime.now();
    final soapDuration = responseTime.difference(startTime);
    print(
      'TIMING: SOAP response received at ${responseTime.toIso8601String()}',
    );
    print('TIMING: SOAP request took ${soapDuration.inMilliseconds}ms');

    // Now that the SOAP response has been received, set a timer to display the status message
    // for 2 seconds before re-enabling the keypad and clearing the message
    _statusMessageTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        // Debug: Log when the status message is cleared
        print(
          'TIMING: Status message cleared at ${DateTime.now().toIso8601String()}',
        );
        print(
          'TIMING: Total display time: ${DateTime.now().difference(responseTime).inMilliseconds}ms',
        );

        setState(() {
          _isKeypadDisabled = false;
          // Clear the last punch to hide the status message
          context.read<PunchProvider>().clearLastPunch();
        });
      }
    });
  }

  Future<void> _openAdminScreen() async {
    final isAuthenticated = await showAdminPasswordDialog(context);
    if (isAuthenticated && mounted) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const AdminScreen()));
      // Reload provider and check connectivity after admin screen is closed
      if (mounted) {
        final provider = context.read<PunchProvider>();
        // Check connectivity first
        await provider.checkConnectivity();
        // Then initialize camera
        await provider.initializeCamera();
      }
    }
  }

  // Employee name display
  final String _employeeName = '';

  // Method to build a number key for the keypad with visual feedback
  Widget _buildNumberKey(String number) {
    // Consistent size for all buttons
    const double buttonSize = 92.0; // 15% larger than original 80x80
    const double padding = 4.0;

    return Padding(
      padding: const EdgeInsets.all(padding),
      child: Material(
        color:
            _isKeypadDisabled
                ? AppTheme.numberKeys.withOpacity(
                  0.5,
                ) // Greyed out when disabled
                : AppTheme.numberKeys,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap:
              _isKeypadDisabled
                  ? null // Disable the button when keypad is disabled
                  : () {
                    // Add haptic feedback
                    HapticFeedback.lightImpact();

                    // Allow up to 9 digits for ID
                    if (_idController.text.length < 9) {
                      setState(() {
                        _idController.text += number;
                      });
                    }
                  },
          child: Container(
            width: buttonSize,
            height: buttonSize,
            alignment: Alignment.center,
            child: Text(
              number,
              style: TextStyle(
                fontSize: 32,
                color:
                    _isKeypadDisabled
                        ? AppTheme.defaultText.withOpacity(
                          0.5,
                        ) // Greyed out text when disabled
                        : AppTheme.defaultText,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Method to build the numeric keypad with improved layout
  Widget _buildNumericKeypad() {
    // Consistent spacing
    const double rowSpacing = 8.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Row 1: 1, 2, 3, Backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberKey('1'),
            _buildNumberKey('2'),
            _buildNumberKey('3'),
            // Backspace key with visual feedback
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Material(
                color:
                    _isKeypadDisabled
                        ? AppTheme.backspaceKey.withOpacity(
                          0.5,
                        ) // Greyed out when disabled
                        : AppTheme.backspaceKey,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap:
                      _isKeypadDisabled
                          ? null // Disable the button when keypad is disabled
                          : () {
                            // Add haptic feedback
                            HapticFeedback.mediumImpact();

                            // Remove last character
                            if (_idController.text.isNotEmpty) {
                              setState(() {
                                _idController.text = _idController.text
                                    .substring(
                                      0,
                                      _idController.text.length - 1,
                                    );
                              });
                            }
                          },
                  child: Container(
                    width: 92.0,
                    height: 92.0,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.backspace,
                      color:
                          _isKeypadDisabled
                              ? Colors.white.withOpacity(
                                0.5,
                              ) // Greyed out when disabled
                              : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: rowSpacing),

        // Row 2: 4, 5, 6, Clear
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNumberKey('4'),
            _buildNumberKey('5'),
            _buildNumberKey('6'),
            // Clear key with visual feedback
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Material(
                color:
                    _isKeypadDisabled
                        ? AppTheme.clearKey.withOpacity(
                          0.5,
                        ) // Greyed out when disabled
                        : AppTheme.clearKey,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap:
                      _isKeypadDisabled
                          ? null // Disable the button when keypad is disabled
                          : () {
                            // Add haptic feedback
                            HapticFeedback.mediumImpact();

                            // Clear the text field
                            setState(() {
                              _idController.clear();
                            });
                          },
                  child: Container(
                    width: 92.0,
                    height: 92.0,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.cancel, // Changed to cancel icon as per UI_Plan.md
                      color:
                          _isKeypadDisabled
                              ? Colors.white.withOpacity(
                                0.5,
                              ) // Greyed out when disabled
                              : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: rowSpacing),

        // Create a row that contains two rows (for 7,8,9 and 0) and the submit button
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Column for 7,8,9 and 0
            Column(
              children: [
                // Row with 7, 8, 9
                Row(
                  children: [
                    _buildNumberKey('7'),
                    _buildNumberKey('8'),
                    _buildNumberKey('9'),
                  ],
                ),
                SizedBox(height: rowSpacing),
                // Row with 0
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 100), // Space for one button + padding
                    _buildNumberKey('0'),
                    SizedBox(width: 100), // Space for one button + padding
                  ],
                ),
              ],
            ),

            // Submit button spanning 2 rows
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: Material(
                color:
                    _isKeypadDisabled
                        ? AppTheme.mainGreen.withOpacity(
                          0.5,
                        ) // Greyed out when disabled
                        : AppTheme.mainGreen,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap:
                      _isKeypadDisabled
                          ? null // Disable the button when keypad is disabled
                          : (_idController.text.isNotEmpty
                              ? () async {
                                // Add haptic feedback
                                HapticFeedback.heavyImpact();

                                // Submit the ID
                                await _handlePunch();
                              }
                              : null),
                  child: Opacity(
                    opacity:
                        (_isKeypadDisabled || _idController.text.isEmpty)
                            ? 0.5
                            : 1.0,
                    child: Container(
                      width: 92.0, // Same width as other buttons
                      height: 196.0, // Height of 2 buttons + spacing
                      alignment: Alignment.center,
                      child: Icon(
                        Icons
                            .check_circle, // Changed to check_circle icon as per UI_Plan.md
                        color:
                            _isKeypadDisabled
                                ? Colors.white.withOpacity(
                                  0.5,
                                ) // Greyed out when disabled
                                : Colors.white,
                        size: 48, // Larger icon
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(color: AppTheme.windowBackground),
        child: SafeArea(
          child: Consumer<PunchProvider>(
            builder: (context, provider, child) {
              return Row(
                children: [
                  // Column 1: Small column with online indicator
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.05,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Online indicator at the bottom
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            children: [
                              Icon(
                                provider.isOnline ? Icons.wifi : Icons.wifi_off,
                                color:
                                    provider.isOnline
                                        ? AppTheme.successColor
                                        : AppTheme.errorColor,
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              RotatedBox(
                                quarterTurns: 3, // Rotate text to vertical
                                child: Text(
                                  provider.isOnline
                                      ? (provider.currentLanguage == 'en'
                                          ? 'ONLINE'
                                          : 'EN LÍNEA')
                                      : (provider.currentLanguage == 'en'
                                          ? 'OFFLINE'
                                          : 'SIN CONEXIÓN'),
                                  style: TextStyle(
                                    color:
                                        provider.isOnline
                                            ? AppTheme.successColor
                                            : AppTheme.errorColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Column 2: Employee ID input and keypad
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.45,
                    child: Column(
                      children: [
                        // MSI Logo
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Image.asset(
                            'assets/images/msi_logo.png',
                            height: 100, // Larger logo
                          ),
                        ),

                        // Employee ID Input
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Container(
                            width: 400, // Fixed width
                            padding: const EdgeInsets.symmetric(
                              vertical: 16.0,
                              horizontal: 24.0,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.darkerFrames,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.mainGreen,
                                width: 2,
                              ),
                            ),
                            child: Text(
                              _idController.text.isEmpty
                                  ? provider.currentLanguage == 'en'
                                      ? 'Enter Employee ID'
                                      : 'Ingrese ID de Empleado'
                                  : _idController.text,
                              style: TextStyle(
                                fontSize: 32,
                                color:
                                    _idController.text.isEmpty
                                        ? AppTheme.defaultText.withOpacity(
                                          0.5,
                                        ) // Dimmed text for placeholder
                                        : AppTheme
                                            .defaultText, // Full opacity for entered text
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),

                        // Employee Name Display - Get name from provider's lastPunch
                        if (provider.lastPunch != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            child: Container(
                              width: 400, // Same width as ID entry
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                                horizontal: 24.0,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.frontFrames,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                provider.lastPunch!.displayName,
                                style: TextStyle(
                                  fontSize: 24,
                                  color: AppTheme.defaultText,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),

                        // Numeric Keypad
                        Expanded(child: _buildNumericKeypad()),
                      ],
                    ),
                  ),

                  // Column 3: Date/Time, Camera, Status
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.5,
                    child: Column(
                      children: [
                        // Language and Admin Controls
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Language buttons - left justified
                              Row(
                                children: [
                                  // English Button
                                  Container(
                                    margin: const EdgeInsets.only(right: 8.0),
                                    decoration: BoxDecoration(
                                      color: AppTheme.frontFrames,
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          provider.currentLanguage == 'en'
                                              ? Border.all(
                                                color: AppTheme.mainGreen,
                                                width: 2,
                                              )
                                              : null,
                                    ),
                                    child: TextButton.icon(
                                      icon: const Text(
                                        '🇺🇸',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      label: Text(
                                        'English',
                                        style: TextStyle(
                                          color: AppTheme.defaultText,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (provider.currentLanguage != 'en') {
                                          provider.toggleLanguage();
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Spanish Button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppTheme.frontFrames,
                                      borderRadius: BorderRadius.circular(8),
                                      border:
                                          provider.currentLanguage == 'es'
                                              ? Border.all(
                                                color: AppTheme.mainGreen,
                                                width: 2,
                                              )
                                              : null,
                                    ),
                                    child: TextButton.icon(
                                      icon: const Text(
                                        '🇪🇸',
                                        style: TextStyle(fontSize: 20),
                                      ),
                                      label: Text(
                                        'Español',
                                        style: TextStyle(
                                          color: AppTheme.defaultText,
                                        ),
                                      ),
                                      onPressed: () {
                                        if (provider.currentLanguage != 'es') {
                                          provider.toggleLanguage();
                                        }
                                      },
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // Admin Button - right justified
                              Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.frontFrames,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.settings,
                                    color: AppTheme.defaultText,
                                  ),
                                  onPressed: _openAdminScreen,
                                  tooltip:
                                      provider.currentLanguage == 'en'
                                          ? 'Admin Settings'
                                          : 'Configuración de Administrador',
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Date and Time Display - Centered in column 2
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Container(
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: AppTheme.darkerFrames,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: StreamBuilder(
                              stream: Stream.periodic(
                                const Duration(seconds: 1),
                              ),
                              builder: (context, snapshot) {
                                final now = DateTime.now();
                                // Convert to 12-hour format
                                final hour12 =
                                    now.hour > 12
                                        ? now.hour - 12
                                        : (now.hour == 0 ? 12 : now.hour);
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .center, // Center alignment
                                  children: [
                                    // Date - format based on language
                                    Text(
                                      provider.currentLanguage == 'en'
                                          // English format: Friday, April 11, 2025
                                          ? '${_getWeekday(now, provider.currentLanguage)}, ${_getMonth(now, provider.currentLanguage)} ${now.day}, ${now.year}'
                                          // Spanish format: Viernes, 11 de Abril de 2025
                                          : '${_getWeekday(now, provider.currentLanguage)}, ${now.day} de ${_getMonth(now, provider.currentLanguage).toLowerCase()} de ${now.year}',
                                      style:
                                          Theme.of(
                                            context,
                                          ).textTheme.headlineMedium,
                                      textAlign:
                                          TextAlign.center, // Center text
                                    ),
                                    const SizedBox(height: 8),
                                    // Time in 12-hour format
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment
                                              .center, // Center the row
                                      crossAxisAlignment:
                                          CrossAxisAlignment.baseline,
                                      textBaseline: TextBaseline.alphabetic,
                                      children: [
                                        Text(
                                          '${hour12.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.displayLarge,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _getAmPm(now),
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.headlineMedium,
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),

                        // Camera Preview with proper aspect ratio
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 12.0,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              // Fixed container height (50% of screen height)
                              final containerHeight =
                                  MediaQuery.of(context).size.height * 0.5;
                              // Calculate width based on 4:3 aspect ratio (width = height * 4/3)
                              final containerWidth =
                                  containerHeight * (4.0 / 3.0);

                              return Center(
                                child: Container(
                                  height: containerHeight, // Fixed height
                                  width:
                                      containerWidth, // Width based on 4:3 aspect ratio
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppTheme.frontFrames,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    color: AppTheme.darkerFrames,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child:
                                        provider.isCameraInitialized
                                            ? ClipRect(
                                              child: OverflowBox(
                                                alignment: Alignment.center,
                                                child: Transform.rotate(
                                                  angle:
                                                      -1.5708, // 90 degrees counter-clockwise
                                                  child: FittedBox(
                                                    fit: BoxFit.cover,
                                                    child: SizedBox(
                                                      width:
                                                          containerHeight, // Use container height as width after rotation
                                                      height:
                                                          containerWidth, // Use container width as height after rotation (4:3 ratio)
                                                      child:
                                                          provider
                                                              .cameraController!
                                                              .buildPreview(),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            )
                                            : Center(
                                              child: Text(
                                                'CAMERA PREVIEW',
                                                style: TextStyle(
                                                  color: AppTheme.defaultText,
                                                  fontSize: 18,
                                                ),
                                              ),
                                            ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),

                        // Status Messages - Transparent background, IBM Plex Sans Medium font
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 1.0,
                          ),
                          child: Container(
                            width: double.infinity, // Full width of column
                            height: 80, // Adjusted height for larger font size
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 4.0,
                            ),
                            decoration: BoxDecoration(
                              // Transparent background
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize:
                                      MainAxisSize
                                          .min, // Take minimum space needed
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Error Display
                                    if (provider.error != null)
                                      Text(
                                        provider.error!,
                                        style: GoogleFonts.ibmPlexSans(
                                          color: AppTheme.errorColor,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 30,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow:
                                            TextOverflow
                                                .ellipsis, // Show ellipsis for overflow
                                        maxLines: 2, // Limit to 2 lines
                                      ),
                                    // Last Punch Display
                                    if (provider.lastPunch != null)
                                      Text(
                                        provider.lastPunch!.getStatusMessage(
                                          provider.currentLanguage,
                                        ),
                                        style: GoogleFonts.ibmPlexSans(
                                          color:
                                              provider.lastPunch!.hasError
                                                  ? AppTheme.errorColor
                                                  : AppTheme.successColor,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 30,
                                        ),
                                        textAlign: TextAlign.center,
                                        overflow:
                                            TextOverflow
                                                .ellipsis, // Show ellipsis for overflow
                                        maxLines: 2, // Limit to 2 lines
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // Helper methods for date and time formatting
  String _getWeekday(DateTime date, String language) {
    if (language == 'en') {
      final weekdays = [
        'Sunday',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
      ];
      return weekdays[date.weekday % 7];
    } else {
      // Spanish weekdays (capitalized for UI consistency)
      final weekdays = [
        'Domingo',
        'Lunes',
        'Martes',
        'Miércoles',
        'Jueves',
        'Viernes',
        'Sábado',
      ];
      return weekdays[date.weekday % 7];
    }
  }

  String _getMonth(DateTime date, String language) {
    if (language == 'en') {
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return months[date.month - 1];
    } else {
      // Spanish months (capitalized for UI consistency)
      final months = [
        'Enero',
        'Febrero',
        'Marzo',
        'Abril',
        'Mayo',
        'Junio',
        'Julio',
        'Agosto',
        'Septiembre',
        'Octubre',
        'Noviembre',
        'Diciembre',
      ];
      return months[date.month - 1];
    }
  }

  String _getAmPm(DateTime date) {
    return date.hour < 12 ? 'AM' : 'PM';
  }
}
