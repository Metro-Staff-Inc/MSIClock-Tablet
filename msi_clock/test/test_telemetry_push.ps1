# Test Telemetry Push Script (PowerShell)
# This script sends a fake telemetry payload to test the new API

# Configuration
$API_ENDPOINT = "https://admin.msistaff.com/api/telemetry"
$API_TOKEN = "a49755e6-4445-4731-b349-60fd1e41b88f"

# Generate current timestamp in ISO-8601 format (UTC)
$TIMESTAMP = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")

# Sample telemetry data
$payload = @{
    mac_address = "AA:BB:CC:DD:EE:FF"
    device_name = "Test-Tablet-01"
    location = "Development Lab"
    reported_at = $TIMESTAMP
    battery_pct = 85
    free_space = 5368709120    # 5GB in bytes
    total_space = 16106127360  # 15GB in bytes
    app_version = "1.0.11-test"
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Testing Telemetry API" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Endpoint: $API_ENDPOINT"
Write-Host "Timestamp: $TIMESTAMP"
Write-Host ""
Write-Host "Payload:"
Write-Host ($payload | ConvertTo-Json -Depth 10)
Write-Host ""
Write-Host "Sending request..." -ForegroundColor Yellow
Write-Host ""

try {
    # Send the request
    $headers = @{
        "Content-Type" = "application/json"
        "Authorization" = "Bearer $API_TOKEN"
    }
    
    $jsonBody = $payload | ConvertTo-Json -Depth 10
    
    $response = Invoke-WebRequest -Uri $API_ENDPOINT `
        -Method POST `
        -Headers $headers `
        -Body $jsonBody `
        -UseBasicParsing
    
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Response" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "HTTP Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Body:"
    
    $responseBody = $response.Content | ConvertFrom-Json
    Write-Host ($responseBody | ConvertTo-Json -Depth 10)
    Write-Host ""
    
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ SUCCESS: Telemetry sent successfully!" -ForegroundColor Green
        if ($responseBody.device_id) {
            Write-Host "   Device ID: $($responseBody.device_id)" -ForegroundColor Green
        }
    }
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    $errorBody = ""
    
    try {
        $stream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $errorBody = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()
    }
    catch {
        $errorBody = $_.Exception.Message
    }
    
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "Response" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "HTTP Status: $statusCode" -ForegroundColor Red
    Write-Host ""
    Write-Host "Body:"
    
    try {
        $errorJson = $errorBody | ConvertFrom-Json
        Write-Host ($errorJson | ConvertTo-Json -Depth 10)
    }
    catch {
        Write-Host $errorBody
    }
    
    Write-Host ""
    
    switch ($statusCode) {
        401 {
            Write-Host "❌ ERROR: Authentication failed (401)" -ForegroundColor Red
            Write-Host "   Check that the API token is correct" -ForegroundColor Yellow
        }
        400 {
            Write-Host "❌ ERROR: Bad request (400)" -ForegroundColor Red
            Write-Host "   The payload format is invalid" -ForegroundColor Yellow
            Write-Host "   Check the error details above" -ForegroundColor Yellow
        }
        { $_ -in 500,502,503,504 } {
            Write-Host "⚠️  ERROR: Server error ($statusCode)" -ForegroundColor Red
            Write-Host "   The server encountered an error" -ForegroundColor Yellow
        }
        default {
            Write-Host "⚠️  Unexpected response code: $statusCode" -ForegroundColor Red
        }
    }
}

Write-Host ""
