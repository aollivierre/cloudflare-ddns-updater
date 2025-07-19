[CmdletBinding()]
param()

# Configuration - EDIT THESE VALUES
$ZoneId = "b5b434545550d4af9e402c2d01516274" 
$AuthEmail = "abdullahollivierre@gmail.com"
$AuthKey = "4894a69299c7d0041074aa98741fab2975e43"  
$RecordName = "rdgateway02.cloudcommand.org"
$LogFile = "C:\Scripts\CloudflareDDNS.log"

# Create log directory if it doesn't exist
$LogDir = Split-Path $LogFile -Parent
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

# Function to write to log
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $LogFile -Append
    Write-Output "$timestamp - $Message"
}

# Function to get current public IP
function Get-PublicIP {
    try {
        $ip = Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 30
        Write-Log "Detected public IP $ip"
        return $ip
    }
    catch {
        Write-Log "ERROR: Failed to get public IP $_"
        return $null
    }
}

# Function to get current Cloudflare DNS record
function Get-CloudflareRecord {
    try {
        $headers = @{
            "X-Auth-Email" = $AuthEmail
            "X-Auth-Key" = $AuthKey
            "Content-Type" = "application/json"
        }
        
        $uri = "https://api.cloudflare.com/client/v4/zones/$ZoneId/dns_records?type=A&name=$RecordName"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        if ($response.success -and $response.result.Count -gt 0) {
            $currentIP = $response.result[0].content
            $recordId = $response.result[0].id
            Write-Log "Current DNS record: $RecordName points to $currentIP (Record ID: $recordId)"
            return @{
                RecordId = $recordId
                CurrentIP = $currentIP
            }
        }
        else {
            Write-Log "ERROR: Failed to retrieve DNS record: $($response.errors | ConvertTo-Json)"
            return $null
        }
    }
    catch {
        Write-Log "ERROR: Failed to query Cloudflare API $_"
        return $null
    }
}

# Function to update DNS record
function Update-CloudflareRecord {
    param(
        [string]$RecordId,
        [string]$NewIP
    )
    
    try {
        $headers = @{
            "X-Auth-Email" = $AuthEmail
            "X-Auth-Key" = $AuthKey
            "Content-Type" = "application/json"
        }
        
        $body = @{
            type = "A"
            name = $RecordName
            content = $NewIP
            ttl = 120
            proxied = $false
        } | ConvertTo-Json
        
        $uri = "https://api.cloudflare.com/client/v4/zones/$ZoneId/dns_records/$RecordId"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body $body
        
        if ($response.success) {
            Write-Log "SUCCESS: Updated $RecordName to $NewIP"
            return $true
        }
        else {
            Write-Log "ERROR: Failed to update DNS record: $($response.errors | ConvertTo-Json)"
            return $false
        }
    }
    catch {
        Write-Log "ERROR: Failed to update Cloudflare record $_"
        return $false
    }
}

# Main execution
Write-Log "=== Cloudflare DDNS Update Started ==="

# Get current public IP
$publicIP = Get-PublicIP
if (!$publicIP) {
    Write-Log "Exiting: Could not determine public IP"
    exit 1
}

# Get current Cloudflare record
$record = Get-CloudflareRecord
if (!$record) {
    Write-Log "Exiting: Could not retrieve Cloudflare record"
    exit 1
}

# Compare and update if needed
if ($publicIP -ne $record.CurrentIP) {
    Write-Log "IP change detected: $($record.CurrentIP) -> $publicIP"
    $success = Update-CloudflareRecord -RecordId $record.RecordId -NewIP $publicIP
    if ($success) {
        Write-Log "DNS record successfully updated"
    }
    else {
        Write-Log "Failed to update DNS record"
    }
}
else {
    Write-Log "No IP change detected. Current IP: $publicIP"
}

Write-Log "=== Cloudflare DDNS Update Completed ===" 