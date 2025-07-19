# Self-contained Cloudflare DDNS Update Script
# Created automatically - do not edit manually

# Configuration
$domain = "cloudcommand.org"
$hostname = "rdgateway02"
$zoneId = "b5b434545550d4af9e402c2d01516274"
$token = "5zG7JLdxRfFiP6tMrLr1n1-8etX1H3t-mS5VpWhA"
$ttl = 120
$recordName = "$hostname.$domain"
$programDataDir = "C:\ProgramData\CloudflareDDNS\logs"
$logFile = "$programDataDir\cloudflare_ddns.log"

# Ensure log directory exists with proper permissions (critical for SYSTEM context)
if (!(Test-Path -Path $programDataDir)) {
    try {
        $null = New-Item -Path $programDataDir -ItemType Directory -Force
        
        # Set permissions for log directory - explicitly add SYSTEM and Everyone
        $acl = Get-Acl -Path $programDataDir
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($systemRule)
        $acl.AddAccessRule($everyoneRule)
        Set-Acl -Path $programDataDir -AclObject $acl
    }
    catch {
        # Write to alternate location if we can't create the directory
        $errorMsg = "Error creating log directory: $_"
        $tempFile = "$env:TEMP\cloudflare_ddns_error.log"
        Add-Content -Path $tempFile -Value $errorMsg -Force
    }
}

# Create log file if it doesn't exist
if (!(Test-Path -Path $logFile)) {
    try {
        $null = New-Item -Path $logFile -ItemType File -Force
        
        # Ensure the log file has the right permissions
        $acl = Get-Acl -Path $logFile
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")
        $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "Allow")
        $acl.AddAccessRule($systemRule)
        $acl.AddAccessRule($everyoneRule)
        Set-Acl -Path $logFile -AclObject $acl
    }
    catch {
        # Write to alternate location if we can't create the log file
        $errorMsg = "Error creating log file: $_"
        $tempFile = "$env:TEMP\cloudflare_ddns_error.log"
        Add-Content -Path $tempFile -Value $errorMsg -Force
    }
}

function Write-Log {
    param (
        [string]$Message,
        [string]$Status = "INFO",
        [string]$Color = "White"
    )
    
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timeStamp] [$Status] $Message"
    
    try {
        # Always write to log file
        Add-Content -Path $logFile -Value $logEntry -Force
        
        # Write to console with color for interactive use
        if ($Host.UI.RawUI.WindowTitle -ne "Task Scheduler") {
            Write-Host $logEntry -ForegroundColor $Color
        }
    }
    catch {
        # Write to alternate location if we can't write to the log file
        $errorMsg = "Error writing to log: $_"
        $tempFile = "$env:TEMP\cloudflare_ddns_error.log"
        Add-Content -Path $tempFile -Value $errorMsg -Force
        Add-Content -Path $tempFile -Value $logEntry -Force
    }
}

function Get-PublicIP {
    try {
        $ip = $null
        $providers = @(
            "https://api.ipify.org",
            "https://ifconfig.me/ip",
            "https://ipinfo.io/ip",
            "https://checkip.amazonaws.com"
        )
        
        foreach ($provider in $providers) {
            try {
                $ip = Invoke-RestMethod -Uri $provider -TimeoutSec 5
                if ($ip -match '\d+\.\d+\.\d+\.\d+') {
                    return $ip.Trim()
                }
            }
            catch {
                # Try next provider
                continue
            }
        }
        
        if (!$ip) {
            Write-Log -Message "Failed to get public IP from any provider" -Status "ERROR" -Color "Red"
            return $null
        }
        
        return $ip.Trim()
    }
    catch {
        Write-Log -Message "Error getting public IP: $_" -Status "ERROR" -Color "Red"
        return $null
    }
}

function Get-CloudflareRecord {
    try {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }
        
        $recordsUri = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?type=A&name=$recordName"
        $response = Invoke-RestMethod -Uri $recordsUri -Headers $headers -Method Get
        
        if ($response.success -and $response.result.Count -gt 0) {
            $record = $response.result[0]
            Write-Log -Message "Found existing DNS record: $($record.name) ($($record.id)) = $($record.content)" -Status "INFO"
            
            return @{
                RecordID = $record.id
                ZoneID = $zoneId
                Name = $record.name
                CurrentIP = $record.content
            }
        }
        else {
            Write-Log -Message "No existing DNS record found for $recordName" -Status "WARNING" -Color "Yellow"
            return $null
        }
    }
    catch {
        Write-Log -Message "Error getting Cloudflare record: $_" -Status "ERROR" -Color "Red"
        return $null
    }
}

function Update-DNSRecord {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ZoneID,
        
        [Parameter(Mandatory=$true)]
        [string]$RecordID,
        
        [Parameter(Mandatory=$true)]
        [string]$NewIP
    )
    
    try {
        $headers = @{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }
        
        $body = @{
            "content" = $NewIP
            "name" = $recordName
            "type" = "A"
            "ttl" = $ttl
        } | ConvertTo-Json
        
        $updateUri = "https://api.cloudflare.com/client/v4/zones/$ZoneID/dns_records/$RecordID"
        $response = Invoke-RestMethod -Uri $updateUri -Headers $headers -Method Put -Body $body
        
        if ($response.success) {
            Write-Log -Message "Successfully updated DNS record to $NewIP" -Status "SUCCESS" -Color "Green"
            return $true
        }
        else {
            Write-Log -Message "Failed to update DNS record: $($response.errors | ConvertTo-Json)" -Status "ERROR" -Color "Red"
            return $false
        }
    }
    catch {
        Write-Log -Message "Error updating DNS record: $_" -Status "ERROR" -Color "Red"
        return $false
    }
}

# Main execution logic
function Update-CloudflareDNSRecord {
    Write-Log -Message "=== Cloudflare DDNS Update Started ===" -Status "INFO"
    
    try {
        # Get public IP
        $publicIP = Get-PublicIP
        if (!$publicIP) {
            Write-Log -Message "Exiting: Could not determine public IP" -Status "ERROR" -Color "Red"
            return $false
        }
        
        # Get Cloudflare record
        $record = Get-CloudflareRecord
        if (!$record) {
            Write-Log -Message "Exiting: Could not retrieve Cloudflare record" -Status "ERROR" -Color "Red"
            return $false
        }
        
        # Check if IP has changed
        if ($record.CurrentIP -ne $publicIP) {
            Write-Log -Message "IP change detected: $($record.CurrentIP) -> $publicIP" -Status "INFO"
            
            # Update the DNS record
            $updateResult = Update-DNSRecord -ZoneID $record.ZoneID -RecordID $record.RecordID -NewIP $publicIP
            
            if ($updateResult) {
                Write-Log -Message "SUCCESS: Updated $recordName to $publicIP" -Status "SUCCESS" -Color "Green"
                return $true
            }
            else {
                Write-Log -Message "Failed to update DNS record" -Status "ERROR" -Color "Red"
                return $false
            }
        }
        else {
            Write-Log -Message "No IP change detected. Current IP: $publicIP" -Status "INFO"
            return $true
        }
    }
    catch {
        Write-Log -Message "ERROR: Unexpected error during update: $_" -Status "ERROR" -Color "Red"
        return $false
    }
    finally {
        Write-Log -Message "=== Cloudflare DDNS Update Completed ===" -Status "INFO"
    }
}

# Run the update
Update-CloudflareDNSRecord
