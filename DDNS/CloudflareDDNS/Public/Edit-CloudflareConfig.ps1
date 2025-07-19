function Edit-CloudflareConfig {
    [CmdletBinding()]
    param()
    
    Write-Host "Current Cloudflare DDNS Configuration:" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Zone ID        " -NoNewline -ForegroundColor White
    Write-Host " $($script:Config['ZoneId'])" -ForegroundColor Yellow
    Write-Host "Domain         " -NoNewline -ForegroundColor White
    Write-Host " $($script:Config['Domain'])" -ForegroundColor Yellow
    Write-Host "Host           " -NoNewline -ForegroundColor White
    Write-Host " $($script:Config['HostName'])" -ForegroundColor Yellow
    Write-Host "Full DNS Record" -NoNewline -ForegroundColor White
    Write-Host " $($script:Config['HostName']).$($script:Config['Domain'])" -ForegroundColor Green
    Write-Host "TTL            " -NoNewline -ForegroundColor White
    Write-Host " $($script:Config['TTL']) seconds" -ForegroundColor Yellow
    Write-Host "Record Type    " -NoNewline -ForegroundColor White
    Write-Host " $($script:Config['RecordType'])" -ForegroundColor Yellow
    Write-Host "Proxied        " -NoNewline -ForegroundColor White
    Write-Host " $($script:Config['Proxied'])" -ForegroundColor Yellow
    Write-Host "API Token      " -NoNewline -ForegroundColor White
    $apiTokenPrefix = if ($script:Config['ApiToken'].Length -ge 5) { $script:Config['ApiToken'].Substring(0, 5) } else { $script:Config['ApiToken'] }
    Write-Host " $apiTokenPrefix..." -ForegroundColor Yellow
    Write-Host "Config Storage " -NoNewline -ForegroundColor White
    if ($script:Config['EncryptionEnabled']) {
        Write-Host "Encrypted" -ForegroundColor Green
    }
    else {
        Write-Host "Plain text (insecure)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Log Files:" -ForegroundColor Cyan
    Write-Host "Log File " -NoNewline -ForegroundColor White
    Write-Host " $script:LogFile" -ForegroundColor Gray
    Write-Host ""
    
    # Menu for configuration options
    Write-Host "Configuration Options:" -ForegroundColor Cyan
    Write-Host "1: Edit configuration" -ForegroundColor Green
    Write-Host "2: How to create a Cloudflare API token" -ForegroundColor Green
    Write-Host "3: Toggle encryption" -ForegroundColor Green
    Write-Host "4: Export configuration" -ForegroundColor Green
    Write-Host "5: Import configuration" -ForegroundColor Green
    Write-Host "B: Back to main menu" -ForegroundColor Green
    Write-Host ""
    
    $configChoice = Read-Host "Enter your choice (1-5 or B)"
    
    switch ($configChoice.ToUpper()) {
        "1" {
            # Edit the configuration
            Write-Host "`nEditing configuration values:" -ForegroundColor Cyan
            Write-Host "(Press Enter to keep current value)`n" -ForegroundColor Yellow
            
            # Prompt for each value
            $newZoneId = Read-Host "Zone ID [$($script:Config['ZoneId'])]"
            $newApiToken = Read-Host "API Token [$($script:Config['ApiToken'].Substring(0, 5))...]"
            $newDomain = Read-Host "Domain [$($script:Config['Domain'])]"
            $newHostName = Read-Host "Host [$($script:Config['HostName'])]"
            $newTTL = Read-Host "TTL [$($script:Config['TTL'])]"
            $newRecordType = Read-Host "Record Type [$($script:Config['RecordType'])]"
            $newProxied = Read-Host "Proxied (true/false) [$($script:Config['Proxied'])]"
            
            # Replace empty values with current values
            if (-not [string]::IsNullOrWhiteSpace($newZoneId)) { $script:Config['ZoneId'] = $newZoneId }
            if (-not [string]::IsNullOrWhiteSpace($newApiToken)) { $script:Config['ApiToken'] = $newApiToken }
            if (-not [string]::IsNullOrWhiteSpace($newDomain)) { $script:Config['Domain'] = $newDomain }
            if (-not [string]::IsNullOrWhiteSpace($newHostName)) { $script:Config['HostName'] = $newHostName }
            if (-not [string]::IsNullOrWhiteSpace($newTTL)) { $script:Config['TTL'] = [int]$newTTL }
            if (-not [string]::IsNullOrWhiteSpace($newRecordType)) { $script:Config['RecordType'] = $newRecordType }
            if (-not [string]::IsNullOrWhiteSpace($newProxied)) {
                if ($newProxied.ToLower() -eq "true") {
                    $script:Config['Proxied'] = $true
                } elseif ($newProxied.ToLower() -eq "false") {
                    $script:Config['Proxied'] = $false
                }
            }
            
            # Save the configuration
            $configPath = Join-Path -Path $script:Config.ConfigDir -ChildPath $script:ConfigFileName
            
            try {
                # Always update the JSON config for compatibility
                $configToExport = @{}
                foreach ($key in $script:Config.Keys) {
                    if ($key -eq "ApiToken" -and $script:Config["EncryptionEnabled"]) {
                        $configToExport[$key] = "ENCRYPTED - SEE SECURE CONFIG FILE"
                    }
                    else {
                        $configToExport[$key] = $script:Config[$key]
                    }
                }
                
                $configToExport | ConvertTo-Json | Set-Content -Path $configPath -Force
                
                # If encryption is enabled, also update secure config
                if ($script:Config["EncryptionEnabled"]) {
                    Export-CloudflareDDNSSecureConfig -Config $script:Config
                }
                
                Write-Host "`nConfiguration has been updated successfully!" -ForegroundColor Green
                Write-CloudflareDDNSLog -Message "Configuration updated via editor" -Status "INFO" -Color "Green"
            }
            catch {
                Write-Host "`nError updating configuration: $_" -ForegroundColor Red
                Write-CloudflareDDNSLog -Message "Error updating configuration: $_" -Status "ERROR" -Color "Red"
            }
        }
        "2" {
            # Display information about creating a Cloudflare API token
            Clear-Host
            Write-Host "How to Create a Cloudflare API Token" -ForegroundColor Cyan
            Write-Host "====================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "1. Log in to your Cloudflare dashboard at https://dash.cloudflare.com" -ForegroundColor White
            Write-Host "2. Go to 'My Profile' > 'API Tokens' > 'Create Token'" -ForegroundColor White
            Write-Host "3. Select 'Create Custom Token'" -ForegroundColor White
            Write-Host "4. Name it 'DDNS Updater'" -ForegroundColor White
            Write-Host "5. Under 'Permissions':" -ForegroundColor White
            Write-Host "   - Zone - DNS - Edit" -ForegroundColor Yellow
            Write-Host "   - Zone - Zone - Read" -ForegroundColor Yellow
            Write-Host "6. Under 'Zone Resources':" -ForegroundColor White
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
        "3" {
            # Toggle encryption
            $script:Config['EncryptionEnabled'] = -not $script:Config['EncryptionEnabled']
            
            if ($script:Config['EncryptionEnabled']) {
                Write-Host "Encryption has been enabled for sensitive configuration data." -ForegroundColor Green
                
                # Create secure config file
                if (Export-CloudflareDDNSSecureConfig -Config $script:Config) {
                    Write-Host "Secure configuration file created successfully." -ForegroundColor Green
                }
                else {
                    Write-Host "Failed to create secure configuration file." -ForegroundColor Red
                    $script:Config['EncryptionEnabled'] = $false
                }
            }
            else {
                Write-Host "WARNING: Encryption has been disabled. API tokens will be stored in plain text." -ForegroundColor Red
                Write-Host "This is not recommended for production environments." -ForegroundColor Red
                
                # Confirm disabling encryption
                $confirm = Read-Host "Are you sure you want to disable encryption? (Y/N)"
                if ($confirm.ToUpper() -ne "Y") {
                    $script:Config['EncryptionEnabled'] = $true
                    Write-Host "Encryption remains enabled." -ForegroundColor Green
                }
                else {
                    # Remove secure config file
                    $encryptedConfigPath = Join-Path -Path $script:Config.ConfigDir -ChildPath $script:EncryptedConfigFileName
                    if (Test-Path $encryptedConfigPath) {
                        Remove-Item -Path $encryptedConfigPath -Force
                    }
                    
                    # Update regular config with actual values
                    $configPath = Join-Path -Path $script:Config.ConfigDir -ChildPath $script:ConfigFileName
                    $script:Config | ConvertTo-Json | Set-Content -Path $configPath -Force
                    
                    Write-Host "Encryption has been disabled. Secure configuration file removed." -ForegroundColor Yellow
                }
            }
            
            # Log encryption change
            Write-CloudflareDDNSLog -Message "Configuration encryption setting changed to: $($script:Config['EncryptionEnabled'])" -Status "INFO" -Color "Yellow"
        }
        "4" {
            # Export configuration to a user-selected location
            $exportPath = Read-Host "Enter path to export configuration (or press Enter for Desktop)"
            
            if ([string]::IsNullOrWhiteSpace($exportPath)) {
                $exportPath = [Environment]::GetFolderPath("Desktop")
            }
            
            if (-not (Test-Path $exportPath -PathType Container)) {
                Write-Host "Invalid export path. Export cancelled." -ForegroundColor Red
            }
            else {
                $exportFilePath = Join-Path -Path $exportPath -ChildPath "CloudflareDDNS-ExportedConfig.json"
                try {
                    # Export a clean version of the config (remove secure data)
                    $exportConfig = @{}
                    foreach ($key in $script:Config.Keys) {
                        if ($key -eq "ApiToken") {
                            $exportConfig[$key] = "API_TOKEN_PLACEHOLDER"
                        }
                        else {
                            $exportConfig[$key] = $script:Config[$key]
                        }
                    }
                    
                    $exportConfig | ConvertTo-Json | Set-Content -Path $exportFilePath -Force
                    Write-Host "Configuration exported to: $exportFilePath" -ForegroundColor Green
                    Write-Host "NOTE: API Token was not exported for security reasons." -ForegroundColor Yellow
                    Write-CloudflareDDNSLog -Message "Configuration exported to: $exportFilePath" -Status "INFO" -Color "Green"
                }
                catch {
                    Write-Host "Error exporting configuration: $_" -ForegroundColor Red
                    Write-CloudflareDDNSLog -Message "Error exporting configuration: $_" -Status "ERROR" -Color "Red"
                }
            }
        }
        "5" {
            # Import configuration from a user-selected location
            $importPath = Read-Host "Enter path to JSON configuration file to import"
            
            if ([string]::IsNullOrWhiteSpace($importPath) -or (-not (Test-Path $importPath -PathType Leaf))) {
                Write-Host "Invalid import file path. Import cancelled." -ForegroundColor Red
            }
            else {
                try {
                    $importedConfig = Get-Content -Path $importPath -Raw | ConvertFrom-Json
                    
                    # Convert to hashtable
                    $importedConfigHashtable = @{}
                    foreach ($property in $importedConfig.PSObject.Properties) {
                        $importedConfigHashtable[$property.Name] = $property.Value
                    }
                    
                    # Preserve API Token if importing config doesn't have one
                    if (-not $importedConfigHashtable.ApiToken -or $importedConfigHashtable.ApiToken -eq "API_TOKEN_PLACEHOLDER") {
                        $importedConfigHashtable.ApiToken = $script:Config['ApiToken']
                    }
                    
                    # Update current config
                    foreach ($key in $importedConfigHashtable.Keys) {
                        $script:Config[$key] = $importedConfigHashtable[$key]
                    }
                    
                    # Save updated config
                    $configPath = Join-Path -Path $script:Config.ConfigDir -ChildPath $script:ConfigFileName
                    
                    # Always update the JSON config for compatibility
                    $configToExport = @{}
                    foreach ($key in $script:Config.Keys) {
                        if ($key -eq "ApiToken" -and $script:Config['EncryptionEnabled']) {
                            $configToExport[$key] = "ENCRYPTED - SEE SECURE CONFIG FILE"
                        }
                        else {
                            $configToExport[$key] = $script:Config[$key]
                        }
                    }
                    
                    $configToExport | ConvertTo-Json | Set-Content -Path $configPath -Force
                    
                    # If encryption is enabled, also update secure config
                    if ($script:Config['EncryptionEnabled']) {
                        Export-CloudflareDDNSSecureConfig -Config $script:Config
                    }
                    
                    Write-Host "Configuration imported successfully!" -ForegroundColor Green
                    Write-CloudflareDDNSLog -Message "Configuration imported from: $importPath" -Status "INFO" -Color "Green"
                }
                catch {
                    Write-Host "Error importing configuration: $_" -ForegroundColor Red
                    Write-CloudflareDDNSLog -Message "Error importing configuration: $_" -Status "ERROR" -Color "Red"
                }
            }
        }
        "B" {
            # Return to main menu
            return
        }
        default {
            Write-Host "Invalid selection." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
    
    Write-Host ""
    Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
    Read-Host
} 