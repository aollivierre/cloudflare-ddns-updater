function Get-CloudflareRecord {
    [CmdletBinding()]
    param()
    
    try {
        # Load configuration
        $apiToken = $script:Config['ApiToken']
        $zoneID = $script:Config['ZoneId']
        $recordType = $script:Config['RecordType']
        $hostName = $script:Config['HostName']
        $domain = $script:Config['Domain']
        
        $RecordName = "$hostName.$domain"
        
        # Ensure we have both API token and Zone ID (not empty or placeholders)
        $placeholders = @("YOUR_ZONE_ID", "your-zone-id", "your_zone_id", "API_TOKEN_PLACEHOLDER", "your-api-token", "YOUR_API_TOKEN")
        
        if ([string]::IsNullOrEmpty($apiToken) -or [string]::IsNullOrEmpty($zoneID)) {
            Write-CloudflareDDNSLog -Message "API token or Zone ID is missing" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
            return $null
        }
        
        if ($placeholders -contains $apiToken -or $placeholders -contains $zoneID) {
            Write-CloudflareDDNSLog -Message "API token or Zone ID contains placeholder values. Please update your configuration." -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
            return $null
        }
        
        # Set up the headers
        $headers = @{
            "Authorization" = "Bearer $apiToken"
            "Content-Type" = "application/json"
        }
        
        # Query Cloudflare API
        $uri = "https://api.cloudflare.com/client/v4/zones/$zoneID/dns_records?type=$recordType&name=$RecordName"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        if ($response.success -and $response.result.Count -gt 0) {
            $record = $response.result[0]
            $recordId = $record.id
            $currentIP = $record.content
            
            Write-CloudflareDDNSLog -Message "Current DNS record: $RecordName points to $currentIP (Record ID: $recordId)" -LogFilePath $script:LogFile
            
            return @{
                ZoneID = $zoneID
                RecordID = $recordId
                CurrentIP = $currentIP
            }
        }
        else {
            Write-CloudflareDDNSLog -Message "ERROR: Failed to retrieve DNS record: $($response.errors | ConvertTo-Json)" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
            return $null
        }
    }
    catch {
        Write-CloudflareDDNSLog -Message "ERROR: Failed to query Cloudflare API $_" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
        return $null
    }
} 