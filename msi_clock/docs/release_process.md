# Release Process - MSI Clock

## Overview

This document outlines the standard process for creating and deploying new releases of the MSI Clock application.

---

## Step 1: Update Version Number

Edit [`pubspec.yaml`](../pubspec.yaml):

```yaml
version: X.Y.Z+B # Format: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

**Version Format:**

- **MAJOR.MINOR.PATCH** - Semantic version (e.g., 1.0.6)
- **+BUILD_NUMBER** - Build number for Play Store (e.g., +7)

**When to increment:**

- **MAJOR** (1.x.x) - Breaking changes, major rewrites
- **MINOR** (x.1.x) - New features, significant changes
- **PATCH** (x.x.1) - Bug fixes, minor improvements
- **BUILD** (+x) - **Always increment** for each release

**Example:**

```yaml
# Current: version: 1.0.5+6
# Next release: version: 1.0.6+7
```

---

## Step 2: Update CHANGELOG

Edit [`CHANGELOG.md`](../CHANGELOG.md) and add the new version at the top:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added

- New features or functionality

### Changed

- Changes to existing functionality

### Fixed

- Bug fixes

### Removed

- Removed features or functionality

### Security

- Security-related changes
```

**Example:**

```markdown
## [1.0.6] - 2026-02-28

### Fixed

- Fixed issue with camera temporary files
- Corrected database cleanup scheduling

### Added

- Storage monitoring in battery check-in
- New logging for storage metrics
```

---

## Step 3: Install Dependencies

Run in terminal:

```bash
flutter pub get
```

This ensures all dependencies are up to date.

---

## Step 4: Build the Release

### Option A: Build Release APK (Recommended for Direct Installation)

```bash
flutter build apk --release
```

**Output location:**

```
build/app/outputs/flutter-apk/app-release.apk
```

### Option B: Build App Bundle (for Google Play Store)

```bash
flutter build appbundle --release
```

**Output location:**

```
build/app/outputs/bundle/release/app-release.aab
```

### Option C: Build Split APKs (Smaller file sizes)

```bash
flutter build apk --release --split-per-abi
```

**Output location:**

```
build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
build/app/outputs/flutter-apk/app-x86_64-release.apk
```

---

## Step 5: Test the Release

### Install on Test Device

```bash
flutter install --release
```

Or manually install the APK on a test device.

### Verification Checklist

- [ ] App launches successfully
- [ ] Punch recording works
- [ ] Camera functionality works
- [ ] Offline mode works
- [ ] Settings can be changed
- [ ] Battery check-in sends data
- [ ] Logs are being created
- [ ] No crashes or errors

---

## Step 6: Commit and Tag

```bash
# Stage all changes
git add .

# Commit with descriptive message
git commit -m "Release vX.Y.Z - Brief description

- Key change 1
- Key change 2
- Key change 3"

# Create annotated tag
git tag -a vX.Y.Z -m "Version X.Y.Z

Brief description of release.

See CHANGELOG.md for full details."

# Push commits and tags
git push origin main
git push origin vX.Y.Z
```

**Example:**

```bash
git commit -m "Release v1.0.6 - Storage improvements

- Fix camera temp file cleanup
- Add automatic database cleanup
- Add storage monitoring"

git tag -a v1.0.6 -m "Version 1.0.6

Storage improvements and monitoring.

See CHANGELOG.md for full details."

git push origin main
git push origin v1.0.6
```

---

## Step 7: Create GitHub Release (Optional)

1. Go to repository → **Releases** → **Draft a new release**
2. **Choose tag:** Select the tag you just created (e.g., `v1.0.6`)
3. **Release title:** `vX.Y.Z - Brief Description`
4. **Description:** Copy from CHANGELOG.md and add any deployment notes
5. **Attach files:** Upload `app-release.apk`
6. **Publish release**

---

## Step 8: Deploy to Devices

### Method 1: Manual Installation

1. Copy APK to accessible location
2. Transfer to tablets (USB, network, cloud)
3. Install on each tablet:
   - Enable "Install from Unknown Sources" if needed
   - Tap APK file to install
   - App will update automatically

### Method 2: Using Update Service

1. Upload APK to your update server
2. Update version info endpoint
3. Tablets will auto-update on next check (hourly)

---

## Step 9: Post-Release Monitoring

- Monitor logs for errors
- Check that new features work as expected
- Verify no regressions in existing functionality
- Monitor battery check-in data
- Watch for crash reports

---

## Quick Reference

### Version Numbering

```
X.Y.Z+B
│ │ │ │
│ │ │ └─ Build number (increment every build)
│ │ └─── Patch version (bug fixes)
│ └───── Minor version (new features)
└─────── Major version (breaking changes)
```

### Common Commands

```bash
# Get dependencies
flutter pub get

# Clean build
flutter clean

# Build release APK
flutter build apk --release

# Build app bundle
flutter build appbundle --release

# Install on connected device
flutter install --release

# Check version
grep "version:" pubspec.yaml
```

### File Locations

- **Version:** `pubspec.yaml` (line 4)
- **Changelog:** `CHANGELOG.md`
- **APK:** `build/app/outputs/flutter-apk/app-release.apk`
- **Bundle:** `build/app/outputs/bundle/release/app-release.aab`

---

## Troubleshooting

### Build Fails

```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --release
```

### Version Conflict

- Ensure build number is higher than previous release
- Check current version in `pubspec.yaml`
- Verify no duplicate tags exist

### APK Too Large

```bash
# Build split APKs per ABI (smaller files)
flutter build apk --release --split-per-abi
```

### Gradle Issues

```bash
# Clear Gradle cache
cd android
./gradlew clean
cd ..
flutter build apk --release
```

---

## Best Practices

1. **Always test** on a physical device before deploying
2. **Increment build number** for every release
3. **Update CHANGELOG** with all changes
4. **Create git tags** for version tracking
5. **Keep backups** of previous APKs
6. **Monitor logs** after deployment
7. **Document breaking changes** clearly
8. **Test offline mode** if applicable
9. **Verify auto-update** works (if using update service)
10. **Communicate** with users about significant changes

---

## Release Checklist

- [ ] Version number updated in `pubspec.yaml`
- [ ] CHANGELOG.md updated with changes
- [ ] Dependencies installed (`flutter pub get`)
- [ ] Release built successfully
- [ ] Tested on physical device
- [ ] All features verified working
- [ ] Changes committed to git
- [ ] Git tag created
- [ ] Changes pushed to repository
- [ ] GitHub release created (if applicable)
- [ ] APK deployed to devices
- [ ] Post-release monitoring active
