# Cloudflare R2 Log Upload Configuration

## Overview

The MSI Clock app automatically uploads log files to Cloudflare R2 storage daily at 2 AM. This document explains how the R2 credentials are configured and secured.

## Security Approach

The R2 credentials are stored in a **gitignored file** that is NOT committed to the repository. This ensures sensitive credentials remain secure while still being included in the compiled app.

## File Structure

```
lib/config/
├── r2_credentials.dart          # GITIGNORED - Contains actual credentials
└── r2_credentials.dart.example  # Template file (committed to Git)
```

## Setup for New Developers

1. **Copy the template file:**

   ```bash
   cp lib/config/r2_credentials.dart.example lib/config/r2_credentials.dart
   ```

2. **Fill in the actual credentials** in `r2_credentials.dart`:
   - Account ID: Your Cloudflare account ID
   - Bucket Name: The R2 bucket name (e.g., `msi-tablet-logs`)
   - Access Key ID: R2 API access key ID
   - Secret Access Key: R2 API secret access key

3. **Verify the file is gitignored:**
   ```bash
   git status
   # r2_credentials.dart should NOT appear in the list
   ```

## How It Works

### Default Settings

When the app first runs, it creates a `settings.json` file with default R2 credentials from `r2_credentials.dart`:

```dart
'r2': {
  'accountId': R2Credentials.accountId,
  'bucketName': R2Credentials.bucketName,
  'accessKeyId': R2Credentials.accessKeyId,
  'secretAccessKey': R2Credentials.secretAccessKey,
}
```

### Upload Process

1. **Scheduled Upload**: Every day at 2 AM, the app automatically uploads yesterday's log file
2. **Manual Upload**: Admins can manually trigger an upload from the Admin Settings screen
3. **Upload Location**: Logs are uploaded to: `logs/{deviceName}/{log-YYYY-MM-DD.txt}`

### Authentication

The app uses **AWS Signature Version 4** authentication to securely upload files to Cloudflare R2:

- Creates a canonical request with the file payload
- Generates a signature using HMAC-SHA256 with the secret key
- Adds an Authorization header to the HTTP PUT request

## Getting R2 Credentials

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Navigate to **R2 Object Storage**
3. Create a bucket (if you haven't already)
4. Go to **Manage R2 API Tokens**
5. Create an API token with **read/write permissions** for your bucket
6. Note your **Account ID** from the R2 overview page

## Security Best Practices

✅ **DO:**

- Keep `r2_credentials.dart` in `.gitignore`
- Use R2 API tokens with minimal permissions (read/write to specific bucket only)
- Rotate credentials periodically
- Use different credentials for development and production

❌ **DON'T:**

- Commit `r2_credentials.dart` to Git
- Share credentials in chat/email
- Use admin-level R2 tokens
- Hardcode credentials in other files

## Troubleshooting

### Upload Fails with "R2 configuration not found"

**Cause**: The `r2_credentials.dart` file doesn't exist or wasn't imported correctly.

**Solution**:

1. Verify `lib/config/r2_credentials.dart` exists
2. Check that it contains valid credentials
3. Rebuild the app: `flutter clean && flutter build apk`

### Upload Fails with 403 Forbidden

**Cause**: Invalid credentials or insufficient permissions.

**Solution**:

1. Verify credentials are correct in Cloudflare dashboard
2. Ensure the API token has read/write permissions for the bucket
3. Check that the bucket name matches exactly

### Upload Fails with Network Error

**Cause**: Device doesn't have internet connectivity.

**Solution**:

1. Check device network connection
2. Verify firewall isn't blocking Cloudflare R2 endpoints
3. Check logs for detailed error messages

## Deployment

When deploying to new tablets:

1. **Build the APK** with credentials already included:

   ```bash
   flutter build apk --release
   ```

2. **Install on tablets** - credentials are automatically included in the compiled app

3. **No manual configuration needed** - each tablet will have the R2 credentials built-in

## Monitoring

Check upload status:

- View logs in the app's log directory
- Check the Admin Settings screen for upload status
- Verify files appear in the R2 bucket at: `logs/{deviceName}/`

## Related Files

- [`lib/services/log_upload_service.dart`](../lib/services/log_upload_service.dart) - Upload logic
- [`lib/services/settings_service.dart`](../lib/services/settings_service.dart) - Settings management
- [`lib/services/logger_service.dart`](../lib/services/logger_service.dart) - Logging system
- [`.gitignore`](../.gitignore) - Git ignore rules
