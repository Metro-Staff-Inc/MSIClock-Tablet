# MSI Clock - Tablet Time Clock Application

## Project Overview

MSI Clock is a tablet-based time clock application developed for Metro Staff Inc. It provides a robust solution for employee time tracking with photo verification, designed to operate in kiosk mode on Android tablets.

The application connects to MSI's backend Web Trax system via SOAP services to validate punches and retrieve employee information. It features bilingual support (English/Spanish), offline operation capabilities, and an automatic update system.

Designed primarily for touchscreen tablet devices, MSI Clock provides an intuitive interface for employees to clock in and out while capturing photos for verification and maintaining a secure record of attendance.

## Features

### Core Functionality

- **Employee Time Clock** - Simple numeric keypad for ID entry
- **Photo Verification** - Captures employee photo with each punch
- **Real-time Verification** - Validates punches against backend systems
- **Employee Recognition** - Displays employee names upon successful punch
- **Punch Status Feedback** - Clear visual feedback on punch status
- **Weekly Hours Display** - Shows employees their accumulated hours

### User Experience

- **Bilingual Interface** - Full support for English and Spanish
- **Responsive Design** - Optimized for tablet displays in landscape orientation
- **Touch-Friendly Interface** - Large buttons and clear visuals
- **Visual Feedback** - Status indicators for network, camera, and punch results
- **Kiosk Mode** - Full-screen operation without system UI

### Technical Capabilities

- **Online/Offline Operation** - Functions even without network connectivity
- **Automatic Data Synchronization** - Syncs offline punches when connection is restored
- **Persistent Connections** - Maintains connection to backend with heartbeat
- **Automatic Updates** - Self-updates from GitHub releases
- **Error Recovery** - Automatic retry mechanisms for network operations
- **Admin Configuration** - Password-protected settings interface

## Technical Architecture

MSI Clock is built using the following technologies:

- **Flutter Framework** - Cross-platform UI toolkit
- **Dart Programming Language** - Core application logic
- **SOAP API Integration** - Connection to MSI WebTrax backend services
- **Camera Integration** - Photo capture for employee verification
- **Provider Pattern** - State management across the application
- **GitHub Integration** - Automatic updates via GitHub releases

The application follows a layered architecture:

- **UI Layer** - Flutter widgets and screens
- **Provider Layer** - State management and business logic
- **Service Layer** - SOAP communication, camera control, settings management
- **Model Layer** - Data structures representing punches and configuration

## Installation

### System Requirements

- Android 8.0 (Oreo) or higher
- 2GB RAM minimum (4GB recommended)
- Front-facing camera
- Network connectivity (Wi-Fi or cellular)
- 50MB storage space

### Installation Process

1. Download the latest APK from the [GitHub releases page](https://github.com/metrostaffinc/MSIClock-Tablet/releases)
2. Enable installation from unknown sources in Android settings
3. Install the APK
4. Grant required permissions (camera, storage)
5. Start the application

### Kiosk Mode Setup (Android)

For optimal operation as a dedicated time clock device:

1. In Android settings, set MSI Clock as a device owner app:
   ```
   adb shell dpm set-device-owner com.example.msi_clock/.AdminReceiver
   ```
2. Launch the application, which will automatically enter kiosk mode
3. The device will now operate as a dedicated time clock

## Configuration

### Initial Setup

The application comes pre-configured with default SOAP settings. These can be modified through the Admin screen.

### SOAP Connection Settings

- **Endpoint URL** - The MSI WebTrax server URL (default: https://msiwebtrax.com)
- **Username** - SOAP service authentication username
- **Password** - SOAP service authentication password
- **Client ID** - Organization identifier in the MSI WebTrax system

### Admin Access

- Default admin password: `1234`
- The admin password can be changed in the Admin screen

## Usage

### Employee Time Clock Operation

1. The main screen displays the current date, time, and a numeric keypad
2. Employee enters their ID number using the keypad
3. Upon pressing the submit button (green checkmark):
   - The system captures a photo
   - The punch is transmitted to the backend system
   - The employee's name and status message are displayed
4. The status message indicates whether the punch was successful:
   - "Welcome!" for clock-in
   - "Goodbye!" for clock-out
   - Error messages for issues (e.g., "Not Authorized", "Shift not yet started")

### Language Selection

- Toggle between English and Spanish using the language buttons in the top-right corner
- All UI elements and status messages will update to the selected language

### Online/Offline Indicator

- A connectivity indicator is shown on the screen
- When offline, punches are stored locally
- Stored punches are automatically synchronized when connectivity is restored

## Admin Guide

### Accessing Admin Settings

1. Tap the gear icon in the top-right corner of the main screen
2. Enter the admin password (default: `1234`)
3. The Admin Settings screen will appear

### Configuring SOAP Connection

1. In the Admin Settings screen, locate the "SOAP Configuration" section
2. Update the following fields as needed:
   - Username
   - Password
   - Client ID
   - SOAP Endpoint URL
3. Tap "Save Settings" to apply changes

### Changing Admin Password

1. In the Admin Settings screen, locate the "Admin Password" section
2. Enter the new password in both fields (New Admin Password and Confirm)
3. Tap "Save Settings" to apply changes

### Managing Updates

1. In the Admin Settings screen, locate the "App Version and Updates" section
2. Tap "Check for Updates" to check for newer versions
3. If an update is available, tap "Update Now" to download and install

### Exiting Kiosk Mode

1. In the Admin Settings screen, scroll to the bottom
2. Tap "Close Application"
3. Confirm by tapping "Close App" in the dialog
4. The application will exit kiosk mode and close

## Troubleshooting

### Network Connectivity Issues

- **Symptom**: "Offline" indicator is shown or punches return "Stored offline" message
- **Solution**:
  - Check the Wi-Fi or cellular connection on the device
  - Verify the SOAP endpoint URL in Admin Settings
  - Try alternative endpoints (e.g., http instead of https)
  - Restart the application

### Camera Initialization Problems

- **Symptom**: Camera preview shows "CAMERA PREVIEW" text instead of live view
- **Solution**:
  - Ensure camera permissions are granted
  - Restart the application
  - If problem persists, reboot the device

### Update Failures

- **Symptom**: Unable to download or install updates
- **Solution**:
  - Ensure the device has internet connectivity
  - Check storage permissions
  - Verify there is sufficient storage space
  - Try downloading the APK manually from GitHub

## Development

### Development Environment Setup

1. Install Flutter SDK (version 3.7.2 or higher)
2. Clone the repository:
   ```
   git clone https://github.com/metrostaffinc/MSIClock-Tablet.git
   ```
3. Install dependencies:
   ```
   flutter pub get
   ```
4. Run the application in debug mode:
   ```
   flutter run
   ```

### Project Structure

- **lib/** - Main application code
  - **config/** - Application configuration and theming
  - **models/** - Data models
  - **providers/** - State management
  - **screens/** - UI screens
  - **services/** - Backend services
  - **widgets/** - Reusable UI components
- **assets/** - Static resources

### Key Components

#### Services

- **SOAP Service** - Handles communication with MSI WebTrax SOAP API
- **Punch Service** - Manages the punch recording process
- **Settings Service** - Handles application configuration
- **Update Service** - Manages automatic updates

#### Providers

- **Punch Provider** - Central state management for the punch process

#### Screens

- **Clock Screen** - Main time clock interface
- **Admin Screen** - Configuration interface
- **Initialization Screen** - Handles startup processes

### Building for Production

```
flutter build apk --release
```

## Deployment

### Creating Release Builds

1. Update the version number in `pubspec.yaml`
2. Build the APK:
   ```
   flutter build apk --release
   ```
3. Sign the APK with your keystore

### Publishing Updates to GitHub

1. Create a new release on GitHub
2. Upload the signed APK
3. Include release notes describing changes

### Deployment to Tablets

1. Install the application using the APK
2. Configure the tablet for kiosk mode
3. Set up auto-start on boot if needed
4. Automatic updates will handle future version updates

### Tablet Setup

1. Designed for Lenovo M11 Tablets with 1080p resolution
2. Navigate to Github to install .APK
   1. https://github.com/Metro-Staff-Inc/MSIClock-Tablet/releases
   2. Add App to Main Screen
3. Removal of unneeded preinstalled software
   1. B
   2. MusicFX
   3. MyScript Calculator 2
   4. Nebo
   5. Recorder
   6. WPS Office
4. Settings
   1. Display
      1. Dark Mode
      2. Screen Timeout = Never
   2. Sounds = Mute All
5. General Settings
   1. Taskbar = Off
6. Remove all Application Icons from Home Screens

## License

Copyright © Metro Staff Inc. All rights reserved.
