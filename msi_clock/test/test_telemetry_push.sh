#!/bin/bash

# Test Telemetry Push Script
# This script sends a fake telemetry payload to test the new API

# Configuration
API_ENDPOINT="https://admin.msistaff.com/api/telemetry"
API_TOKEN="a49755e6-4445-4731-b349-60fd1e41b88f"

# Generate current timestamp in ISO-8601 format (UTC)
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

# Sample telemetry data
MAC_ADDRESS="AA:BB:CC:DD:EE:FF"
DEVICE_NAME="Test-Tablet-01"
LOCATION="Development Lab"
BATTERY_PCT=85
FREE_SPACE=5368709120    # 5GB in bytes
TOTAL_SPACE=16106127360  # 15GB in bytes
APP_VERSION="1.0.11-test"

# Create JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "mac_address": "$MAC_ADDRESS",
  "device_name": "$DEVICE_NAME",
  "location": "$LOCATION",
  "reported_at": "$TIMESTAMP",
  "battery_pct": $BATTERY_PCT,
  "free_space": $FREE_SPACE,
  "total_space": $TOTAL_SPACE,
  "app_version": "$APP_VERSION"
}
EOF
)

echo "=========================================="
echo "Testing Telemetry API"
echo "=========================================="
echo ""
echo "Endpoint: $API_ENDPOINT"
echo "Timestamp: $TIMESTAMP"
echo ""
echo "Payload:"
echo "$JSON_PAYLOAD" | jq '.' 2>/dev/null || echo "$JSON_PAYLOAD"
echo ""
echo "Sending request..."
echo ""

# Send the request
RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d "$JSON_PAYLOAD")

# Extract HTTP status code (last line)
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
# Extract response body (all but last line)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

echo "=========================================="
echo "Response"
echo "=========================================="
echo "HTTP Status: $HTTP_CODE"
echo ""
echo "Body:"
echo "$RESPONSE_BODY" | jq '.' 2>/dev/null || echo "$RESPONSE_BODY"
echo ""

# Interpret the response
case $HTTP_CODE in
  200)
    echo "✅ SUCCESS: Telemetry sent successfully!"
    DEVICE_ID=$(echo "$RESPONSE_BODY" | jq -r '.device_id' 2>/dev/null)
    if [ "$DEVICE_ID" != "null" ] && [ -n "$DEVICE_ID" ]; then
      echo "   Device ID: $DEVICE_ID"
    fi
    ;;
  401)
    echo "❌ ERROR: Authentication failed (401)"
    echo "   Check that the API token is correct"
    ;;
  400)
    echo "❌ ERROR: Bad request (400)"
    echo "   The payload format is invalid"
    echo "   Check the error details above"
    ;;
  500|502|503|504)
    echo "⚠️  ERROR: Server error ($HTTP_CODE)"
    echo "   The server encountered an error"
    ;;
  *)
    echo "⚠️  Unexpected response code: $HTTP_CODE"
    ;;
esac

echo ""
