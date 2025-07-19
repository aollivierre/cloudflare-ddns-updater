function Configure-CloudflareAPIToken {
    [CmdletBinding()]
    param (
        [string]$ApiToken = "",
        [string]$ZoneId = "",
        [string]$Domain = "",
        [string]$HostName = "",
        [switch]$AsSystem
    )
    
    # Check if encryption is enabled and if we're not running as SYSTEM
    # Only show encryption warning if not running as SYSTEM
    $isSystem = $false
    try {
        # Try to use Test-RunningAsSystem from AsSystem module if available
        if (Get-Command -Name Test-RunningAsSystem -ErrorAction SilentlyContinue) {
            $isSystem = Test-RunningAsSystem
        }
    }
    catch {
        Write-Verbose "Error checking system status: $_"
    }
    
    if ($script:Config['EncryptionEnabled'] -and -not $isSystem -and -not $AsSystem) {
        $params = @{}
        if ($ApiToken) { $params['ApiToken'] = $ApiToken }
        if ($ZoneId) { $params['ZoneId'] = $ZoneId }
        if ($Domain) { $params['Domain'] = $Domain }
        if ($HostName) { $params['HostName'] = $HostName }
        
        return Invoke-ConfigOperationAsSystem -Operation "Configure" -Parameters $params
    }
    
    # Regular configuration logic
    Write-Host ""
    Write-Host "===== Cloudflare API Token Configuration =====" -ForegroundColor Cyan
    
    # If running with parameters (likely from SYSTEM elevation), use those directly
    if ($AsSystem -and $ApiToken) {
        $script:Config["ApiToken"] = $ApiToken
        $script:ConfigNeedsToken = $false
        
        if ($ZoneId) {
            $script:Config["ZoneId"] = $ZoneId
        }
        
        if ($Domain) {
            $script:Config["Domain"] = $Domain
        }
        
        if ($HostName) {
            $script:Config["HostName"] = $HostName
        }
        
        # Save the updated config
        try {
            $configPath = Join-Path -Path $script:Config.ConfigDir -ChildPath $script:ConfigFileName
            
            if ($script:Config["EncryptionEnabled"]) {
                Export-CloudflareDDNSSecureConfig -Config $script:Config
                return $true
            }
            else {
                # Save to regular config
                $script:Config | ConvertTo-Json | Set-Content -Path $configPath -Force
                return $true
            }
        }
        catch {
            Write-Error "Error saving API Token configuration: $_"
            return $false
        }
    }
    
    # Interactive configuration
    Write-Host ""
    Write-Host "You will need a Cloudflare API Token with:" -ForegroundColor White
    Write-Host "- Zone:DNS:Edit permission" -ForegroundColor Yellow
    Write-Host "- Zone:Zone:Read permission" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Would you like to see instructions for creating a token?" -ForegroundColor White
    $showInstructions = Read-Host "Enter 'Y' for instructions or any other key to continue (Y/N)"
    
    if ($showInstructions.ToUpper() -eq 'Y') {
        Clear-Host
        Write-Host "How to Create a Cloudflare API Token" -ForegroundColor Cyan
        Write-Host "====================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Log in to your Cloudflare dashboard at https://dash.cloudflare.com" -ForegroundColor White
        Write-Host "2. Go to 'My Profile' > 'API Tokens' > 'Create Token'" -ForegroundColor White
        Write-Host "3. Select 'Create Custom Token'" -ForegroundColor White
        Write-Host "4. Name it 'DDNS Updater'" -ForegroundColor White
        Write-Host "5. Under 'Permissions'" -ForegroundColor White
        Write-Host "   - Zone - DNS - Edit" -ForegroundColor Yellow
        Write-Host "   - Zone - Zone - Read" -ForegroundColor Yellow
        Write-Host "6. Under 'Zone Resources'" -ForegroundColor White
        Write-Host "   - Include - Specific zone - your domain (e.g., $($script:Config['Domain']))" -ForegroundColor Yellow
        Write-Host "7. IMPORTANT: Set 'TTL' to 'No expiration' or your token will expire and break DDNS" -ForegroundColor Red
        Write-Host "8. Click 'Continue to summary' then 'Create Token'" -ForegroundColor White
        Write-Host "9. Copy the generated token (you'll only see it once)" -ForegroundColor White
        Write-Host ""
        Write-Host "How to Find Your Zone ID:" -ForegroundColor Cyan
        Write-Host "=========================" -ForegroundColor Cyan
        Write-Host "1. Go to your Cloudflare dashboard" -ForegroundColor White
        Write-Host "2. Select your domain" -ForegroundColor White
        Write-Host "3. On the Overview page, scroll down to the API section" -ForegroundColor White
        Write-Host "4. Your Zone ID is listed there (a 32-character alphanumeric string)" -ForegroundColor White
        Write-Host ""
        
        $openDashboard = Read-Host "Would you like to open Cloudflare dashboard in your browser? (Y/N)"
        if ($openDashboard.ToUpper() -eq "Y") {
            Start-Process "https://dash.cloudflare.com"
            Write-Host "Browser opened to Cloudflare dashboard. Create your token and then return here." -ForegroundColor Yellow
            Write-Host "Press Enter when you're ready to continue..." -ForegroundColor Cyan
            Read-Host
        }
    }
    
    Write-Host ""
    Write-Host "Please enter your Cloudflare API Token:" -ForegroundColor Yellow
    $newApiToken = Read-Host -AsSecureString "API Token"
    
    if ($newApiToken.Length -gt 0) {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($newApiToken)
        $script:Config["ApiToken"] = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        $script:ConfigNeedsToken = $false
        
        # Now prompt for Zone ID
        Write-Host ""
        Write-Host "Please enter your Cloudflare Zone ID:" -ForegroundColor Yellow
        if ($script:Config["ZoneId"] -eq "YOUR_ZONE_ID") {
            Write-Host "(This is a 32-character ID found in your Cloudflare dashboard)" -ForegroundColor Cyan
        }
        else {
            Write-Host "Current Zone ID is: $($script:Config["ZoneId"])" -ForegroundColor Cyan
            Write-Host "Press Enter to keep current value or enter a new Zone ID" -ForegroundColor Cyan
        }
        
        $newZoneId = Read-Host "Zone ID"
        
        if (-not [string]::IsNullOrWhiteSpace($newZoneId)) {
            $script:Config["ZoneId"] = $newZoneId
        }
        
        # Prompt for domain info if it's still the default
        if ($script:Config["Domain"] -eq "yourdomain.com") {
            Write-Host ""
            Write-Host "Please enter your domain name:" -ForegroundColor Yellow
            $newDomain = Read-Host "Domain (e.g. example.com)"
            
            if (-not [string]::IsNullOrWhiteSpace($newDomain)) {
                $script:Config["Domain"] = $newDomain
            }
            
            Write-Host ""
            Write-Host "Please enter the hostname for the DNS record:" -ForegroundColor Yellow
            Write-Host "(Use '@' for the root domain, or a subdomain like 'www')" -ForegroundColor Cyan
            $newHostname = Read-Host "Hostname"
            
            if (-not [string]::IsNullOrWhiteSpace($newHostname)) {
                $script:Config["HostName"] = $newHostname
            }
        }
        
        # Save the updated config
        try {
            $configPath = Join-Path -Path $script:Config.ConfigDir -ChildPath $script:ConfigFileName
            
            if ($script:Config["EncryptionEnabled"]) {
                Export-CloudflareDDNSSecureConfig -Config $script:Config
                Write-Host "Saved new API token to secure configuration." -ForegroundColor Green
            }
            else {
                # Save to regular config
                $script:Config | ConvertTo-Json | Set-Content -Path $configPath -Force
                Write-Host "Saved new API token to configuration." -ForegroundColor Green
            }
            
            Write-CloudflareDDNSLog -Message "API Token configured successfully" -Status "SUCCESS" -Color "Green"
            
            # Test the API connection
            Write-Host ""
            Write-Host "Would you like to test the API connection now?" -ForegroundColor Yellow
            $testAPI = Read-Host "Enter 'Y' to test or any other key to skip (Y/N)"
            
            if ($testAPI.ToUpper() -eq 'Y') {
                Test-CloudflareAPIConnection
            }
            
            return $true
        }
        catch {
            Write-Host "Error saving configuration: $_" -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "Error saving API Token configuration: $_" -Status "ERROR" -Color "Red"
            return $false
        }
    }
    else {
        Write-Host "No API token provided. Configuration not updated." -ForegroundColor Red
        return $false
    }
} 