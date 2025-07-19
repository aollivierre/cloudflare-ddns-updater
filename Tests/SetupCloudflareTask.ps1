# Simple script to set up Cloudflare DDNS scheduled task
# Reads directly from config.json and sets up task in SYSTEM context
# This is a standalone script with no module dependencies

# Read the config.json file
$scriptPath = $PSScriptRoot
$configPath = Join-Path -Path $scriptPath -ChildPath "config.json"
$configJson = Get-Content -Path $configPath -Raw | ConvertFrom-Json

# Extract settings from config
$domain = $configJson.settings[0].domain
$hostname = $configJson.settings[0].host
$zoneId = $configJson.settings[0].zone_identifier
$token = $configJson.settings[0].token
$ttl = $configJson.settings[0].ttl
$recordName = "$hostname.$domain"

Write-Host "Setting up DDNS task for $recordName" -ForegroundColor Cyan

# Define log directory - use absolute path for consistency in SYSTEM context
$programDataLogDir = "C:\ProgramData\CloudflareDDNS\logs"
if (!(Test-Path -Path $programDataLogDir)) {
    New-Item -Path $programDataLogDir -ItemType Directory -Force | Out-Null
    
    # Set permissions for log directory - explicitly add SYSTEM and Everyone
    $acl = Get-Acl -Path $programDataLogDir
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($systemRule)
    $acl.AddAccessRule($everyoneRule)
    Set-Acl -Path $programDataLogDir -AclObject $acl
}

# Create log file to ensure it's accessible
$logFilePath = Join-Path -Path $programDataLogDir -ChildPath "cloudflare_ddns.log"
if (!(Test-Path -Path $logFilePath)) {
    New-Item -Path $logFilePath -ItemType File -Force | Out-Null
    
    # Set permissions for log file
    $acl = Get-Acl -Path $logFilePath
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")
    $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "Allow")
    $acl.AddAccessRule($systemRule)
    $acl.AddAccessRule($everyoneRule)
    Set-Acl -Path $logFilePath -AclObject $acl
}

# Create the self-contained update script
$updateScriptPath = Join-Path -Path $scriptPath -ChildPath "Update-CloudflareDNS.ps1"
$updateScript = @'
# Self-contained Cloudflare DDNS Update Script
# Created automatically - do not edit manually

# Configuration
$domain = "{0}"
$hostname = "{1}"
$zoneId = "{2}"
$token = "{3}"
$ttl = {4}
$recordName = "$hostname.$domain"
$programDataDir = "C:\ProgramData\CloudflareDDNS\logs"
$logFile = "$programDataDir\cloudflare_ddns.log"

# Ensure log directory exists with proper permissions (critical for SYSTEM context)
if (!(Test-Path -Path $programDataDir)) {{
    try {{
        $null = New-Item -Path $programDataDir -ItemType Directory -Force
        
        # Set permissions for log directory - explicitly add SYSTEM and Everyone
        $acl = Get-Acl -Path $programDataDir
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
        $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
        $acl.AddAccessRule($systemRule)
        $acl.AddAccessRule($everyoneRule)
        Set-Acl -Path $programDataDir -AclObject $acl
    }}
    catch {{
        # Write to alternate location if we can't create the directory
        $errorMsg = "Error creating log directory: $_"
        $tempFile = "$env:TEMP\cloudflare_ddns_error.log"
        Add-Content -Path $tempFile -Value $errorMsg -Force
    }}
}}

# Create log file if it doesn't exist
if (!(Test-Path -Path $logFile)) {{
    try {{
        $null = New-Item -Path $logFile -ItemType File -Force
        
        # Ensure the log file has the right permissions
        $acl = Get-Acl -Path $logFile
        $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")
        $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "Allow")
        $acl.AddAccessRule($systemRule)
        $acl.AddAccessRule($everyoneRule)
        Set-Acl -Path $logFile -AclObject $acl
    }}
    catch {{
        # Write to alternate location if we can't create the log file
        $errorMsg = "Error creating log file: $_"
        $tempFile = "$env:TEMP\cloudflare_ddns_error.log"
        Add-Content -Path $tempFile -Value $errorMsg -Force
    }}
}}

function Write-Log {{
    param (
        [string]$Message,
        [string]$Status = "INFO",
        [string]$Color = "White"
    )
    
    $timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timeStamp] [$Status] $Message"
    
    try {{
        # Always write to log file
        Add-Content -Path $logFile -Value $logEntry -Force
        
        # Write to console with color for interactive use
        if ($Host.UI.RawUI.WindowTitle -ne "Task Scheduler") {{
            Write-Host $logEntry -ForegroundColor $Color
        }}
    }}
    catch {{
        # Write to alternate location if we can't write to the log file
        $errorMsg = "Error writing to log: $_"
        $tempFile = "$env:TEMP\cloudflare_ddns_error.log"
        Add-Content -Path $tempFile -Value $errorMsg -Force
        Add-Content -Path $tempFile -Value $logEntry -Force
    }}
}}

function Get-PublicIP {{
    try {{
        $ip = $null
        $providers = @(
            "https://api.ipify.org",
            "https://ifconfig.me/ip",
            "https://ipinfo.io/ip",
            "https://checkip.amazonaws.com"
        )
        
        foreach ($provider in $providers) {{
            try {{
                $ip = Invoke-RestMethod -Uri $provider -TimeoutSec 5
                if ($ip -match '\d+\.\d+\.\d+\.\d+') {{
                    return $ip.Trim()
                }}
            }}
            catch {{
                # Try next provider
                continue
            }}
        }}
        
        if (!$ip) {{
            Write-Log -Message "Failed to get public IP from any provider" -Status "ERROR" -Color "Red"
            return $null
        }}
        
        return $ip.Trim()
    }}
    catch {{
        Write-Log -Message "Error getting public IP: $_" -Status "ERROR" -Color "Red"
        return $null
    }}
}}

function Get-CloudflareRecord {{
    try {{
        $headers = @{{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }}
        
        $recordsUri = "https://api.cloudflare.com/client/v4/zones/$zoneId/dns_records?type=A&name=$recordName"
        $response = Invoke-RestMethod -Uri $recordsUri -Headers $headers -Method Get
        
        if ($response.success -and $response.result.Count -gt 0) {{
            $record = $response.result[0]
            Write-Log -Message "Found existing DNS record: $($record.name) ($($record.id)) = $($record.content)" -Status "INFO"
            
            return @{{
                RecordID = $record.id
                ZoneID = $zoneId
                Name = $record.name
                CurrentIP = $record.content
            }}
        }}
        else {{
            Write-Log -Message "No existing DNS record found for $recordName" -Status "WARNING" -Color "Yellow"
            return $null
        }}
    }}
    catch {{
        Write-Log -Message "Error getting Cloudflare record: $_" -Status "ERROR" -Color "Red"
        return $null
    }}
}}

function Update-DNSRecord {{
    param (
        [Parameter(Mandatory=$true)]
        [string]$ZoneID,
        
        [Parameter(Mandatory=$true)]
        [string]$RecordID,
        
        [Parameter(Mandatory=$true)]
        [string]$NewIP
    )
    
    try {{
        $headers = @{{
            "Authorization" = "Bearer $token"
            "Content-Type" = "application/json"
        }}
        
        $body = @{{
            "content" = $NewIP
            "name" = $recordName
            "type" = "A"
            "ttl" = $ttl
        }} | ConvertTo-Json
        
        $updateUri = "https://api.cloudflare.com/client/v4/zones/$ZoneID/dns_records/$RecordID"
        $response = Invoke-RestMethod -Uri $updateUri -Headers $headers -Method Put -Body $body
        
        if ($response.success) {{
            Write-Log -Message "Successfully updated DNS record to $NewIP" -Status "SUCCESS" -Color "Green"
            return $true
        }}
        else {{
            Write-Log -Message "Failed to update DNS record: $($response.errors | ConvertTo-Json)" -Status "ERROR" -Color "Red"
            return $false
        }}
    }}
    catch {{
        Write-Log -Message "Error updating DNS record: $_" -Status "ERROR" -Color "Red"
        return $false
    }}
}}

# Main execution logic
function Update-CloudflareDNSRecord {{
    Write-Log -Message "=== Cloudflare DDNS Update Started ===" -Status "INFO"
    
    try {{
        # Get public IP
        $publicIP = Get-PublicIP
        if (!$publicIP) {{
            Write-Log -Message "Exiting: Could not determine public IP" -Status "ERROR" -Color "Red"
            return $false
        }}
        
        # Get Cloudflare record
        $record = Get-CloudflareRecord
        if (!$record) {{
            Write-Log -Message "Exiting: Could not retrieve Cloudflare record" -Status "ERROR" -Color "Red"
            return $false
        }}
        
        # Check if IP has changed
        if ($record.CurrentIP -ne $publicIP) {{
            Write-Log -Message "IP change detected: $($record.CurrentIP) -> $publicIP" -Status "INFO"
            
            # Update the DNS record
            $updateResult = Update-DNSRecord -ZoneID $record.ZoneID -RecordID $record.RecordID -NewIP $publicIP
            
            if ($updateResult) {{
                Write-Log -Message "SUCCESS: Updated $recordName to $publicIP" -Status "SUCCESS" -Color "Green"
                return $true
            }}
            else {{
                Write-Log -Message "Failed to update DNS record" -Status "ERROR" -Color "Red"
                return $false
            }}
        }}
        else {{
            Write-Log -Message "No IP change detected. Current IP: $publicIP" -Status "INFO"
            return $true
        }}
    }}
    catch {{
        Write-Log -Message "ERROR: Unexpected error during update: $_" -Status "ERROR" -Color "Red"
        return $false
    }}
    finally {{
        Write-Log -Message "=== Cloudflare DDNS Update Completed ===" -Status "INFO"
    }}
}}

# Run the update
Update-CloudflareDNSRecord
'@ -f $domain, $hostname, $zoneId, $token, $ttl

# Write the update script to file
Set-Content -Path $updateScriptPath -Value $updateScript

# Task configuration
$taskName = "CloudflareDDNS"
$taskCommand = "powershell.exe"
$actionArgs = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File ""$updateScriptPath"""

# Delete existing task if it exists
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($taskExists) {
    Write-Host "Removing existing task..."
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
}

# Get the current time for StartBoundary
$startBoundary = (Get-Date).AddMinutes(1).ToString("yyyy-MM-ddTHH:mm:ss.000") + (Get-Date).ToString("zzz")

# Create XML task definition with multiple triggers
$escapedActionArgs = [System.Security.SecurityElement]::Escape($actionArgs)
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\$taskName</URI>
    <Description>Updates Cloudflare DNS records for $recordName when public IP changes</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <TimeTrigger>
      <Repetition>
        <Interval>PT4H</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$startBoundary</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
    <BootTrigger>
      <Enabled>true</Enabled>
      <Delay>PT1M</Delay>
    </BootTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"&gt;&lt;Select Path="Microsoft-Windows-NetworkProfile/Operational"&gt;*[System[(EventID=10000 or EventID=10001)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[(EventID=4202)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <DisallowStartOnRemoteAppSession>false</DisallowStartOnRemoteAppSession>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT72H</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>$taskCommand</Command>
      <Arguments>$escapedActionArgs</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# Register the task using the XML definition
try {
    Register-ScheduledTask -TaskName $taskName -Xml $taskXml -Force | Out-Null
    Write-Host "Task '$taskName' created successfully for $recordName" -ForegroundColor Green
    
    # Start the task immediately
    Start-ScheduledTask -TaskName $taskName
    Write-Host "Task started" -ForegroundColor Green
    Write-Host "Log file: $logFilePath" -ForegroundColor Cyan
}
catch {
    Write-Host "Error creating scheduled task: $_" -ForegroundColor Red
} 