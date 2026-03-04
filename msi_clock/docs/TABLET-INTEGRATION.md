# Tablet Integration Guide

## Overview

This document provides complete specifications for tablet devices to push telemetry data to the MSI Admin application. Tablets should send hourly telemetry updates to monitor device health, battery status, storage capacity, and connectivity.

---

## API Endpoint

### Production URL

```
POST https://admin.msistaff.com/api/telemetry
```

### Development/Testing URL

```
POST http://localhost:3000/api/telemetry
```

---

## Authentication

### Method

Bearer Token Authentication

### Header Required

```
Authorization: Bearer a49755e6-4445-4731-b349-60fd1e41b88f
```

### Security Notes

- The API key is shared across all tablets (single key authentication)
- The key must be included in every request
- Requests without valid authentication will receive a `401 Unauthorized` response
- The API key should be stored securely on the tablet device

---

## Request Format

### HTTP Method

`POST`

### Content Type

```
Content-Type: application/json
```

### Request Headers

```http
POST /api/telemetry HTTP/1.1
Host: admin.msistaff.com
Content-Type: application/json
Authorization: Bearer a49755e6-4445-4731-b349-60fd1e41b88f
```

---

## Request Payload

### JSON Schema

```json
{
  "mac_address": "string (required)",
  "device_name": "string (optional)",
  "location": "string (optional)",
  "reported_at": "string (required, ISO-8601 datetime)",
  "battery_pct": "number (optional, integer 0-100)",
  "free_space": "number (optional, integer, bytes)",
  "total_space": "number (optional, integer, bytes)",
  "app_version": "string (optional, max 50 chars)"
}
```

### Field Specifications

| Field         | Type   | Required | Validation                                                    | Description                                                                              |
| ------------- | ------ | -------- | ------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `mac_address` | string | **Yes**  | Must match regex: `^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$` | Device MAC address in standard format (e.g., `AA:BB:CC:DD:EE:FF` or `AA-BB-CC-DD-EE-FF`) |
| `device_name` | string | No       | 1-255 characters                                              | Human-readable device name                                                               |
| `location`    | string | No       | 1-255 characters                                              | Physical location of the device                                                          |
| `reported_at` | string | **Yes**  | ISO-8601 datetime format                                      | Timestamp when telemetry was collected (UTC recommended)                                 |
| `battery_pct` | number | No       | Integer, 0-100                                                | Current battery percentage                                                               |
| `free_space`  | number | No       | Positive integer                                              | Available storage space in bytes                                                         |
| `total_space` | number | No       | Positive integer                                              | Total storage capacity in bytes                                                          |
| `app_version` | string | No       | Max 50 characters                                             | Version of the tablet application                                                        |

### MAC Address Format

- **Accepted formats:**
  - Colon-separated: `AA:BB:CC:DD:EE:FF`
  - Hyphen-separated: `AA-BB-CC-DD-EE-FF`
- **Case-insensitive:** Both uppercase and lowercase hex digits are accepted
- **Normalization:** The server will normalize MAC addresses to a consistent format internally

### Timestamp Format

- **Format:** ISO-8601 datetime string
- **Examples:**
  - `2026-03-04T01:00:00Z` (UTC)
  - `2026-03-04T01:00:00.000Z` (UTC with milliseconds)
  - `2026-03-03T19:00:00-06:00` (with timezone offset)
- **Recommendation:** Send timestamps in UTC for consistency

### Storage Space

- **Units:** Bytes (not KB, MB, or GB)
- **Type:** Integer values only
- **Example:** For 5.2 GB free space, send `5580800000` (bytes)

---

## Example Requests

### Minimal Request (Required Fields Only)

```json
{
  "mac_address": "AA:BB:CC:DD:EE:FF",
  "reported_at": "2026-03-04T01:00:00Z"
}
```

### Complete Request (All Fields)

```json
{
  "mac_address": "AA:BB:CC:DD:EE:FF",
  "device_name": "Lobby Tablet",
  "location": "Main Office - Lobby",
  "reported_at": "2026-03-04T01:00:00Z",
  "battery_pct": 85,
  "free_space": 5580800000,
  "total_space": 32000000000,
  "app_version": "1.2.3"
}
```

### cURL Example

```bash
curl -X POST https://admin.msistaff.com/api/telemetry \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer a49755e6-4445-4731-b349-60fd1e41b88f" \
  -d '{
    "mac_address": "AA:BB:CC:DD:EE:FF",
    "device_name": "Lobby Tablet",
    "location": "Main Office - Lobby",
    "reported_at": "2026-03-04T01:00:00Z",
    "battery_pct": 85,
    "free_space": 5580800000,
    "total_space": 32000000000,
    "app_version": "1.2.3"
  }'
```

---

## Response Format

### Success Response (200 OK)

```json
{
  "success": true,
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": "Telemetry recorded"
}
```

### Error Responses

#### 401 Unauthorized

**Cause:** Missing or invalid API key

```json
{
  "success": false,
  "error": "Unauthorized"
}
```

#### 400 Bad Request

**Cause:** Invalid payload format or validation failure

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

#### 500 Internal Server Error

**Cause:** Server-side error

```json
{
  "success": false,
  "error": "Internal server error"
}
```

---

## Behavior & Processing

### Device Registration

- **Auto-registration:** Devices are automatically created on first telemetry push
- **Identification:** Devices are uniquely identified by MAC address
- **Updates:** Subsequent pushes from the same MAC address update the existing device

### Data Upsert Logic

1. **Device Record:**
   - Creates new device if MAC address is not found
   - Updates `device_name`, `location`, and `last_seen_at` on every push
   - Preserves `first_seen_at` from initial registration

2. **Telemetry Record:**
   - Telemetry is aggregated by hour (reported_hour)
   - Multiple pushes within the same hour will update the same telemetry record
   - Storage percentage is automatically calculated from `free_space` and `total_space`

### Calculated Fields

- **storage_pct:** Automatically calculated as `((total_space - free_space) / total_space) * 100`
- **reported_hour:** Timestamp truncated to the hour (e.g., `2026-03-04T01:00:00Z`)
- **received_at:** Server timestamp when the request was processed

---

## Recommended Implementation

### Timing

- **Frequency:** Send telemetry once per hour
- **Scheduling:** Align to the top of the hour (e.g., 01:00, 02:00, 03:00)
- **Retry Logic:** Implement exponential backoff for failed requests

### Error Handling

```
1. Attempt to send telemetry
2. If network error or 5xx response:
   - Wait 1 minute, retry
   - Wait 5 minutes, retry
   - Wait 15 minutes, retry
   - Log failure and wait for next scheduled push
3. If 4xx response:
   - Log error details
   - Do not retry (fix the payload issue)
```

### Data Collection

```
Before each hourly push:
1. Collect current battery percentage
2. Query storage information (free/total space in bytes)
3. Get current timestamp in ISO-8601 format
4. Retrieve device MAC address
5. Include app version if available
6. Send POST request with all collected data
```

### Network Considerations

- **Timeout:** Set request timeout to 30 seconds
- **Connection:** Use HTTPS for production endpoint
- **Validation:** Validate payload locally before sending to reduce errors

---

## Testing & Validation

### Test Checklist

- [ ] MAC address is correctly formatted
- [ ] Timestamp is in valid ISO-8601 format
- [ ] Authorization header includes correct Bearer token
- [ ] Storage values are in bytes (not KB/MB/GB)
- [ ] Battery percentage is between 0-100
- [ ] Request succeeds and returns device_id
- [ ] Subsequent requests update the same device

### Validation Tools

You can validate your JSON payload structure using the following TypeScript/Zod schema:

```typescript
import { z } from "zod";

const telemetrySchema = z.object({
  mac_address: z.string().regex(/^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$/),
  device_name: z.string().min(1).max(255).optional(),
  location: z.string().min(1).max(255).optional(),
  reported_at: z.string().datetime(),
  battery_pct: z.number().int().min(0).max(100).optional(),
  free_space: z.number().int().positive().optional(),
  total_space: z.number().int().positive().optional(),
  app_version: z.string().max(50).optional(),
});
```

---

## Monitoring & Alerts

### Device Status

The admin dashboard monitors devices based on telemetry:

- **Online:** Telemetry received within the last 2 hours (configurable)
- **Offline:** No telemetry received for more than 2 hours
- **Battery Alert:** Battery percentage below 20% (configurable)
- **Storage Alert:** Storage usage above 85% (configurable)

### Data Retention

- Telemetry data is retained for 90 days (configurable)
- Older telemetry records are automatically deleted
- Device records are never automatically deleted

---

## Security Requirements

### Transport Security

- **Production:** HTTPS only (TLS 1.2 or higher)
- **Certificate Validation:** Verify SSL certificates

### API Key Storage

- Store the API key securely on the device
- Do not hardcode in source code if possible
- Use device keystore or secure storage mechanisms

### Data Privacy

- MAC addresses are stored but not considered PII
- Location and device names should not contain sensitive information
- No user-identifiable information should be included in telemetry

---

## Troubleshooting

### Common Issues

#### "Unauthorized" Error

- **Check:** Authorization header is present
- **Check:** Bearer token matches exactly (including case)
- **Check:** No extra spaces in the header value

#### "Invalid MAC address format"

- **Check:** MAC address matches pattern `XX:XX:XX:XX:XX:XX` or `XX-XX-XX-XX-XX-XX`
- **Check:** All segments are 2-character hex values
- **Check:** No missing or extra characters

#### "Invalid payload" Error

- **Check:** JSON is properly formatted
- **Check:** `reported_at` is valid ISO-8601 datetime
- **Check:** `battery_pct` is integer between 0-100
- **Check:** Storage values are positive integers

#### No Response / Timeout

- **Check:** Network connectivity
- **Check:** Correct endpoint URL
- **Check:** Firewall/proxy settings allow HTTPS to admin.msistaff.com

---

## Support & Contact

For technical issues or questions about tablet integration:

- Review this documentation thoroughly
- Check the troubleshooting section
- Verify your implementation against the example requests
- Contact the MSI Admin development team with specific error messages and request examples

---

## Changelog

### Version 1.0 (2026-03-04)

- Initial documentation
- Defined telemetry API specification
- Added authentication requirements
- Included example requests and responses
- Added troubleshooting guide
