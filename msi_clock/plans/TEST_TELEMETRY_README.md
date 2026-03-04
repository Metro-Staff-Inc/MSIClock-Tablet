# Telemetry API Test Scripts

These scripts allow you to test the new telemetry API endpoint without needing to deploy the app.

## Available Scripts

### 1. PowerShell Script (Windows)

**File:** `test_telemetry_push.ps1`

**Usage:**

```powershell
.\test_telemetry_push.ps1
```

### 2. Bash Script (Linux/Mac)

**File:** `test_telemetry_push.sh`

**Usage:**

```bash
chmod +x test_telemetry_push.sh
./test_telemetry_push.sh
```

### 3. Simple cURL Command (Any Platform)

**Copy and paste this command:**

```bash
curl -X POST https://admin.msistaff.com/api/telemetry \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer a49755e6-4445-4731-b349-60fd1e41b88f" \
  -d '{
    "mac_address": "AA:BB:CC:DD:EE:FF",
    "device_name": "Test-Tablet-01",
    "location": "Development Lab",
    "reported_at": "2026-03-04T02:00:00.000Z",
    "battery_pct": 85,
    "free_space": 5368709120,
    "total_space": 16106127360,
    "app_version": "1.0.11-test"
  }'
```

**PowerShell equivalent:**

```powershell
$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
$body = @{
    mac_address = "AA:BB:CC:DD:EE:FF"
    device_name = "Test-Tablet-01"
    location = "Development Lab"
    reported_at = $timestamp
    battery_pct = 85
    free_space = 5368709120
    total_space = 16106127360
    app_version = "1.0.11-test"
} | ConvertTo-Json

Invoke-WebRequest -Uri "https://admin.msistaff.com/api/telemetry" `
  -Method POST `
  -Headers @{
    "Content-Type" = "application/json"
    "Authorization" = "Bearer a49755e6-4445-4731-b349-60fd1e41b88f"
  } `
  -Body $body
```

## Test Data Explanation

The scripts send the following sample data:

| Field         | Value               | Description                         |
| ------------- | ------------------- | ----------------------------------- |
| `mac_address` | `AA:BB:CC:DD:EE:FF` | Test MAC address (required)         |
| `device_name` | `Test-Tablet-01`    | Device identifier (optional)        |
| `location`    | `Development Lab`   | Physical location (optional)        |
| `reported_at` | Current UTC time    | ISO-8601 timestamp (required)       |
| `battery_pct` | `85`                | Battery percentage 0-100 (optional) |
| `free_space`  | `5368709120`        | 5GB in bytes (optional)             |
| `total_space` | `16106127360`       | 15GB in bytes (optional)            |
| `app_version` | `1.0.11-test`       | App version string (optional)       |

## Expected Responses

### ✅ Success (200 OK)

```json
{
  "success": true,
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Telemetry recorded"
}
```

### ❌ Authentication Error (401)

```json
{
  "success": false,
  "error": "Unauthorized"
}
```

**Fix:** Check that the API token is correct.

### ❌ Validation Error (400)

```json
{
  "success": false,
  "error": "Invalid payload",
  "details": [
    {
      "code": "invalid_string",
      "path": ["mac_address"],
      "message": "Invalid MAC address format"
    }
  ]
}
```

**Fix:** Check the payload format matches the specification.

### ⚠️ Server Error (500)

```json
{
  "success": false,
  "error": "Internal server error"
}
```

**Fix:** Contact the API administrator.

## Customizing the Test

You can modify the test data in the scripts:

1. **Change MAC Address:** Update `mac_address` to test with different devices
2. **Change Location:** Update `location` to test different locations
3. **Change Storage:** Update `free_space` and `total_space` (must be in bytes)
4. **Change Battery:** Update `battery_pct` (must be 0-100)

## Storage Conversion

The API expects storage values in **bytes**:

| GB    | Bytes          |
| ----- | -------------- |
| 1 GB  | 1,073,741,824  |
| 5 GB  | 5,368,709,120  |
| 10 GB | 10,737,418,240 |
| 15 GB | 16,106,127,360 |
| 16 GB | 17,179,869,184 |
| 32 GB | 34,359,738,368 |

**Formula:** `bytes = GB * 1024 * 1024 * 1024`

## Troubleshooting

### "Command not found: curl"

- **Windows:** Use the PowerShell script instead
- **Linux/Mac:** Install curl: `sudo apt install curl` or `brew install curl`

### "Permission denied"

- **Linux/Mac:** Make the script executable: `chmod +x test_telemetry_push.sh`

### "Cannot be loaded because running scripts is disabled"

- **Windows PowerShell:** Run as Administrator and execute:
  ```powershell
  Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
  ```

### Connection Errors

- Check your internet connection
- Verify the API endpoint is accessible
- Check if a firewall is blocking the request

## API Documentation

For complete API documentation, see:

- [`docs/TABLET-INTEGRATION.md`](docs/TABLET-INTEGRATION.md) - Full API specification
- [`docs/telemetry_api_migration_summary.md`](docs/telemetry_api_migration_summary.md) - Migration guide

## Notes

- The timestamp is automatically generated in UTC format
- All test scripts use the same API token configured in the app
- The test data will appear in the admin dashboard if successful
- You can run these tests as many times as needed
