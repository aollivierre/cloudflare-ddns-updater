function Test-CloudflareAPIConnection {
    [CmdletBinding()]
    param()
    
    Write-Host "Testing Cloudflare API connection..." -ForegroundColor Yellow
    Write-CloudflareDDNSLog -Message "Testing Cloudflare API connection" -Status "INFO" -Color "Yellow"
    
    try {
        $headers = @{
            "Authorization" = "Bearer $($script:Config['ApiToken'])"
            "Content-Type"  = "application/json"
        }
        
        # First test API token validity with a simple request
        Write-Host "Testing API token validity..." -ForegroundColor White
        $verifyTokenUri = "https://api.cloudflare.com/client/v4/user/tokens/verify"
        
        try {
            $tokenResponse = Invoke-RestMethod -Uri $verifyTokenUri -Headers $headers -Method Get -ErrorAction Stop
            
            if ($tokenResponse.success -and $tokenResponse.result.status -eq "active") {
                Write-Host "API token is valid and active" -ForegroundColor Green
                Write-CloudflareDDNSLog -Message "API token verification successful" -Status "SUCCESS" -Color "Green"
            }
            else {
                Write-Host "API token verification failed: $($tokenResponse.errors | ConvertTo-Json -Compress)" -ForegroundColor Red
                Write-CloudflareDDNSLog -Message "API token verification failed: $($tokenResponse.errors | ConvertTo-Json -Compress)" -Status "ERROR" -Color "Red"
                return $false
            }
        }
        catch {
            Write-Host "API token verification failed: $_" -ForegroundColor Red
            Write-Host "Please check that your API token is correct and has not expired" -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "API token verification failed: $_" -Status "ERROR" -Color "Red"
            return $false
        }
        
        # Test Zone endpoint
        Write-Host "Testing Zone access..." -ForegroundColor White
        
        # Encode any special characters in the Zone ID
        $zoneId = [uri]::EscapeDataString($script:Config['ZoneId'])
        $zoneUri = "https://api.cloudflare.com/client/v4/zones/$zoneId"
        
        # Print the URL for troubleshooting
        Write-Verbose "API URL: $zoneUri"
        Write-Verbose "API Token (first 5 chars): $($script:Config['ApiToken'].Substring(0, [Math]::Min(5, $script:Config['ApiToken'].Length)))..."
        
        try {
            $zoneResponse = Invoke-RestMethod -Uri $zoneUri -Headers $headers -Method Get -ErrorAction Stop
        }
        catch {
            if ($_.Exception.Response.StatusCode.value__ -eq 400) {
                Write-Host "Error 400: Bad Request - This usually means the API token or Zone ID format is incorrect." -ForegroundColor Red
                Write-Host "Verify that:" -ForegroundColor Yellow
                Write-Host " - Your API token doesn't contain line breaks or extra spaces" -ForegroundColor Yellow
                Write-Host " - You're using an API Token (not a Global API Key)" -ForegroundColor Yellow
                Write-Host " - Your Zone ID is exactly 32 characters (currently: $($script:Config['ZoneId'].Length) chars)" -ForegroundColor Yellow
                Write-CloudflareDDNSLog -Message "API Connection Test FAILED: 400 Bad Request - Check token format" -Status "ERROR" -Color "Red"
                return $false
            }
            throw  # Rethrow to be caught by the outer try-catch
        }
        
        if ($zoneResponse.success) {
            $zoneName = $zoneResponse.result.name
            Write-Host "Successfully accessed zone: $zoneName" -ForegroundColor Green
            Write-CloudflareDDNSLog -Message "Successfully accessed zone: $zoneName" -Status "SUCCESS" -Color "Green"
        }
        else {
            Write-Host "Zone access FAILED: $($zoneResponse.errors | ConvertTo-Json -Compress)" -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "Zone access failed: $($zoneResponse.errors | ConvertTo-Json -Compress)" -Status "ERROR" -Color "Red"
            return $false
        }
        
        # Test DNS Records endpoint
        Write-Host "Testing DNS Records access..." -ForegroundColor White
        $RecordName = "$($script:Config['HostName']).$($script:Config['Domain'])"
        $dnsUri = "https://api.cloudflare.com/client/v4/zones/$($script:Config['ZoneId'])/dns_records?type=A&name=$RecordName"
        $dnsResponse = Invoke-RestMethod -Uri $dnsUri -Headers $headers -Method Get -ErrorAction Stop
        
        if ($dnsResponse.success) {
            if ($dnsResponse.result.Count -gt 0) {
                $recordIP = $dnsResponse.result[0].content
                $recordId = $dnsResponse.result[0].id
                Write-Host "Successfully accessed DNS record: $RecordName -> $recordIP (ID: $recordId)" -ForegroundColor Green
                Write-CloudflareDDNSLog -Message "Successfully accessed DNS record: $RecordName -> $recordIP" -Status "SUCCESS" -Color "Green"
            }
            else {
                Write-Host "WARNING: DNS record $RecordName not found. It may need to be created." -ForegroundColor Yellow
                Write-CloudflareDDNSLog -Message "DNS record $RecordName not found" -Status "WARNING" -Color "Yellow"
            }
        }
        else {
            Write-Host "DNS Records access FAILED: $($dnsResponse.errors | ConvertTo-Json -Compress)" -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "DNS Records access failed: $($dnsResponse.errors | ConvertTo-Json -Compress)" -Status "ERROR" -Color "Red"
            return $false
        }
        
        Write-Host "`nAPI Connection Test SUCCESSFUL!" -ForegroundColor Green
        Write-Host "Your Cloudflare API credentials are working correctly." -ForegroundColor Green
        Write-CloudflareDDNSLog -Message "API Connection Test SUCCESSFUL" -Status "SUCCESS" -Color "Green"
        return $true
    }
    catch {
        Write-Host "`nAPI Connection Test FAILED: $_" -ForegroundColor Red
        Write-Host "Please check your API Token and Zone ID." -ForegroundColor Red
        
        # Try to extract response content for better error messages
        $errorDetails = ""
        try {
            if ($_.Exception.Response) {
                $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
                $errorDetails = $reader.ReadToEnd() | ConvertFrom-Json
                $reader.Close()
                
                if ($errorDetails.errors) {
                    Write-Host "Error details:" -ForegroundColor Red
                    foreach ($error in $errorDetails.errors) {
                        Write-Host " - $($error.message)" -ForegroundColor Red
                    }
                }
            }
        }
        catch {
            # Unable to get detailed error message
        }
        
        if ($_.Exception.Response.StatusCode.value__ -eq 400) {
            Write-Host "Error 400: Bad Request - The request was malformed or contains invalid parameters." -ForegroundColor Red
            Write-Host "Likely causes:" -ForegroundColor Yellow
            Write-Host " - Zone ID format is incorrect (should be 32 characters with no spaces)" -ForegroundColor Yellow
            Write-Host " - API token contains extra spaces or line breaks" -ForegroundColor Yellow
            Write-Host " - Current Zone ID length: $($script:Config['ZoneId'].Length) characters" -ForegroundColor Yellow
            
            # Specific troubleshooting for Zone ID format
            if ($script:Config['ZoneId'].Length -ne 32) {
                Write-Host "WARNING: Your Zone ID is $($script:Config['ZoneId'].Length) characters long, but should be exactly 32." -ForegroundColor Red
            }
            
            Write-CloudflareDDNSLog -Message "API Connection Test FAILED: 400 Bad Request - Check ID formats" -Status "ERROR" -Color "Red"
        }
        elseif ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Write-Host "Error 401: Unauthorized - Your API token is invalid or expired." -ForegroundColor Red
            Write-Host "Solutions:" -ForegroundColor Yellow
            Write-Host " - Generate a new API token at https://dash.cloudflare.com/profile/api-tokens" -ForegroundColor Yellow
            Write-Host " - Make sure you're using an API Token, not a Global API Key" -ForegroundColor Yellow
            Write-CloudflareDDNSLog -Message "API Connection Test FAILED: 401 Unauthorized - Invalid token" -Status "ERROR" -Color "Red"
        }
        elseif ($_.Exception.Response.StatusCode.value__ -eq 403) {
            Write-Host "Error 403: Forbidden - Your API token doesn't have sufficient permissions." -ForegroundColor Red
            Write-Host "Required permissions:" -ForegroundColor Yellow
            Write-Host " - Zone:DNS:Edit" -ForegroundColor Yellow
            Write-Host " - Zone:Zone:Read" -ForegroundColor Yellow
            Write-CloudflareDDNSLog -Message "API Connection Test FAILED: 403 Forbidden - Insufficient permissions" -Status "ERROR" -Color "Red"
        }
        elseif ($_.Exception.Response.StatusCode.value__ -eq 404) {
            Write-Host "Error 404: Not Found - Check your Zone ID." -ForegroundColor Red
            Write-Host "How to find your Zone ID:" -ForegroundColor Yellow
            Write-Host " 1. Go to https://dash.cloudflare.com/" -ForegroundColor Yellow
            Write-Host " 2. Select your domain" -ForegroundColor Yellow
            Write-Host " 3. Look in the API section of the Overview page" -ForegroundColor Yellow
            Write-Host " 4. Copy the 32-character Zone ID" -ForegroundColor Yellow
            Write-CloudflareDDNSLog -Message "API Connection Test FAILED: 404 Not Found - Invalid Zone ID" -Status "ERROR" -Color "Red"
        }
        else {
            Write-Host "`nGeneral troubleshooting:" -ForegroundColor Yellow
            Write-Host " 1. Check your internet connection" -ForegroundColor Yellow
            Write-Host " 2. Verify your account has access to the domain in Cloudflare" -ForegroundColor Yellow
            Write-Host " 3. Try generating a fresh API token with Zone:DNS:Edit and Zone:Zone:Read permissions" -ForegroundColor Yellow
            Write-CloudflareDDNSLog -Message "API Connection Test FAILED: $_" -Status "ERROR" -Color "Red"
        }
        
        Write-Host "`nWould you like to edit your configuration now? (Y/N)" -ForegroundColor Cyan
        $editConfig = Read-Host
        if ($editConfig.ToUpper() -eq "Y") {
            Edit-CloudflareConfig
        }
        
        return $false
    }
} 