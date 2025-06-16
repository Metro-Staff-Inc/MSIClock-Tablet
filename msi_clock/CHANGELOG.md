# Changelog

All notable changes to the MSI Clock application will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
