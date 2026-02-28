# Changelog

All notable changes to the MSI Clock application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.6] - 2026-02-28

### Fixed

- **CRITICAL:** Fixed camera temporary files not being deleted after each punch, preventing storage accumulation
- Fixed database cleanup not running automatically - now scheduled daily at 3 AM
- Improved storage management to prevent tablets from running out of space

### Added

- Comprehensive logging system with two levels (NORMAL and DEBUG)
- Daily log rotation with automatic cleanup (10-day retention)
- Cloudflare R2 log upload at 2 AM daily with manual upload option
- Storage monitoring in hourly battery check-in (free space, total space, percentage)
- R2 credentials configuration with secure gitignored file
- Admin screen controls for log level selection and manual upload
- Detailed documentation for logging system and storage fixes

### Changed

- Enhanced battery check-in API to include storage metrics
- Updated punch service to immediately delete temporary camera files
- Modified punch sync service to schedule automatic database cleanup
- Added crypto package for R2 authentication (HMAC-SHA256)
- Added disk_space package for storage monitoring

## [1.0.5] - 2025-11-13

### Fixed

- Fixed screen dimming in power saving mode by implementing proper brightness control
- Added screen_brightness package for better control of device brightness
- Improved sleep mode activation and deactivation with proper brightness restoration

## [1.0.4] - 2025-11-13

### Added

- Improved power saving settings in Admin Screen
- Clarified SOAP heartbeat interval setting with better description
- Renamed power saving section for better user understanding

### Changed

- Updated documentation to reflect new power saving settings
- Improved UI labels for better clarity on battery optimization settings
- Reorganized Admin Screen settings for better user experience

## [1.0.3] - 2025-11-10

### Added

- Battery monitoring feature that reports tablet battery level to API hourly
- Automatic retry mechanism for failed battery reports
- Battery API configuration in settings
- Comprehensive error handling for battery monitoring
- Power saving features with sleep mode during inactivity
- Configurable inactivity threshold and heartbeat intervals
- Screen dimming and camera disabling during sleep mode
- New documentation files: battery_monitoring_feature.md and battery_monitoring_admin_integration.md
- "Close Application" button in Admin Screen
- Device MAC address display in Admin Screen

### Fixed

- Fixed issue where IP address was incorrectly displayed instead of MAC address
- Updated battery check-in to include device MAC address in API requests
- Improved MAC address formatting to use XX:XX:XX:XX:XX:XX format

### Changed

- Updated settings service to store battery monitoring configuration
- Added battery_plus package for battery level monitoring
- Enhanced application initialization to include battery monitoring service
- Optimized network operations to reduce battery consumption
- Improved user interface with sleep mode indication

## [1.0.2] - 2025-06-16

### Fixed

- Fixed "Failed to check for updates: 404" error by correcting the GitHub repository URL in the update service
- Improved error handling in the update checking process

## [1.0.1] - 2025-06-16

### Added

- Configurable camera settings with enable/disable functionality
- Image selection capability for when camera is disabled
- Camera settings UI controls in Admin Screen
- Caching mechanism for camera settings to improve performance
- Fallback logic when camera is disabled
- New documentation file: camera_toggle_feature.md

### Changed

- Updated camera preview to show selected image when camera is disabled
- Modified punch service to skip image capture when camera is disabled
- Enhanced README with comprehensive project overview and usage guide
- Improved tablet setup instructions in README
- Updated dependencies to include image_picker package

## [1.0.0] - 2025-05-15

### Added

- Initial release of MSI Clock application
- Employee time clock functionality with punch in/out capability
- Camera integration for capturing employee photos during punches
- SOAP service integration for communication with MSI WebTrax
- Admin panel with configuration options
- Offline mode support
- Automatic updates
- Kiosk mode for tablet deployment
