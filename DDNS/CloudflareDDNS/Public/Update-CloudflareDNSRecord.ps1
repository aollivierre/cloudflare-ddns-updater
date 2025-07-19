function Update-CloudflareDNSRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$UseConsoleLog = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$Silent = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$ForceDirect = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$LogPath
    )
    
    # Determine the log target
    if ($LogPath) {
        $logTarget = $LogPath
    } else {
        $logTarget = $script:LogFile
    }
    
    try {
        # Start log
        Write-CloudflareDDNSLog -Message "=== Cloudflare DDNS Update Started ===" -LogFilePath $logTarget -Console:$UseConsoleLog
        
        # Get the public IP
        $publicIP = Get-PublicIP
        if (!$publicIP) {
            Write-CloudflareDDNSLog -Message "Exiting: Could not determine public IP" -Status "ERROR" -Color "Red" -LogFilePath $logTarget -Console:$UseConsoleLog
            if ($UseConsoleLog) {
                Write-Host "Failed to update DNS record: Could not determine public IP" -ForegroundColor Red
            }
            return $false
        }
        
        # Get the Cloudflare DNS record
        $record = Get-CloudflareRecord
        if (!$record) {
            Write-CloudflareDDNSLog -Message "Exiting: Could not retrieve Cloudflare record" -Status "ERROR" -Color "Red" -LogFilePath $logTarget -Console:$UseConsoleLog
            if ($UseConsoleLog) {
                Write-Host "Failed to update DNS record: Could not retrieve Cloudflare record" -ForegroundColor Red
                Write-Host "Check your configuration and API credentials" -ForegroundColor Yellow
            }
            return $false
        }
        
        # Check if the IP has changed or force update is specified
        if (($record.CurrentIP -ne $publicIP) -or $Force) {
            Write-CloudflareDDNSLog -Message "IP change detected or force update requested: $($record.CurrentIP) -> $publicIP" -LogFilePath $logTarget -Console:$UseConsoleLog
            
            # Update the DNS record
            $updateResult = Update-DNSRecord -ZoneID $record.ZoneID -RecordID $record.RecordID -NewIP $publicIP
            
            if ($updateResult) {
                $RecordName = "$($script:Config['HostName']).$($script:Config['Domain'])"
                Write-CloudflareDDNSLog -Message "SUCCESS: Updated $RecordName to $publicIP" -Status "SUCCESS" -Color "Green" -LogFilePath $logTarget -Console:$UseConsoleLog
                
                if ($UseConsoleLog) {
                    Write-Host ""
                    Write-Host "DNS Record Updated Successfully" -ForegroundColor Green
                    Write-Host "-------------------------" -ForegroundColor Cyan
                    Write-Host "Domain: $RecordName" -ForegroundColor White
                    Write-Host "Previous IP: $($record.CurrentIP)" -ForegroundColor White
                    Write-Host "New IP: $publicIP" -ForegroundColor White
                    Write-Host "-------------------------" -ForegroundColor Cyan
                }
                
                # Update the LastIP and LastUpdate in config
                $script:Config["LastIp"] = $publicIP
                $script:Config["LastUpdate"] = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                
                # Save the updated config
                $configPath = Join-Path -Path $script:Config.ConfigDir -ChildPath $script:ConfigFileName
                $configToExport = @{}
                foreach ($key in $script:Config.Keys) {
                    if ($key -eq "ApiToken" -and $script:Config["EncryptionEnabled"]) {
                        $configToExport[$key] = "ENCRYPTED - SEE SECURE CONFIG FILE"
                    }
                    else {
                        $configToExport[$key] = $script:Config[$key]
                    }
                }
                
                # Save the configuration
                $configToExport | ConvertTo-Json | Set-Content -Path $configPath -Force
                
                # If encryption is enabled, also update secure config
                if ($script:Config["EncryptionEnabled"]) {
                    Export-CloudflareDDNSSecureConfig -Config $script:Config
                }
                
                return $true
            }
            else {
                # Update failed
                if ($UseConsoleLog) {
                    Write-Host "Failed to update DNS record" -ForegroundColor Red
                    Write-Host "Check the log file for more details" -ForegroundColor Yellow
                }
                return $false
            }
        }
        else {
            Write-CloudflareDDNSLog -Message "No IP change detected. Current IP: $publicIP" -LogFilePath $logTarget -Console:$UseConsoleLog
            
            if ($UseConsoleLog) {
                Write-Host ""
                Write-Host "No Update Needed" -ForegroundColor Cyan
                Write-Host "-------------------------" -ForegroundColor Cyan
                Write-Host "Domain: $($script:Config['HostName']).$($script:Config['Domain'])" -ForegroundColor White
                Write-Host "Current IP: $publicIP" -ForegroundColor White
                Write-Host "DNS Record IP: $($record.CurrentIP)" -ForegroundColor White
                Write-Host "Status: DNS record is up to date" -ForegroundColor Green
                Write-Host "-------------------------" -ForegroundColor Cyan
            }
            
            return $true
        }
    }
    catch {
        Write-CloudflareDDNSLog -Message "ERROR: Unexpected error during update: $_" -Status "ERROR" -Color "Red" -LogFilePath $logTarget -Console:$UseConsoleLog
        
        if ($UseConsoleLog) {
            Write-Host "An unexpected error occurred:" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
        
        return $false
    }
    finally {
        Write-CloudflareDDNSLog -Message "=== Cloudflare DDNS Update Completed ===" -LogFilePath $logTarget -Console:$UseConsoleLog
    }
}