function Update-DNSRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZoneID,
        
        [Parameter(Mandatory = $true)]
        [string]$RecordID,
        
        [Parameter(Mandatory = $true)]
        [string]$NewIP
    )
    
    try {
        # Load configuration
        $apiToken = $script:Config['ApiToken']
        $recordType = $script:Config['RecordType']
        $hostName = $script:Config['HostName']
        $domain = $script:Config['Domain']
        $ttl = $script:Config['TTL']
        $proxied = $script:Config['Proxied']
        
        $RecordName = "$hostName.$domain"
        
        # Set up the headers
        $headers = @{
            "Authorization" = "Bearer $apiToken"
            "Content-Type" = "application/json"
        }
        
        # Create the request body
        $body = @{
            type = $recordType
            name = $RecordName
            content = $NewIP
            ttl = $ttl
            proxied = $proxied
        } | ConvertTo-Json
        
        # Update the DNS record
        $uri = "https://api.cloudflare.com/client/v4/zones/$ZoneID/dns_records/$RecordID"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body $body
        
        if ($response.success) {
            return $true
        }
        else {
            Write-CloudflareDDNSLog -Message "ERROR: Failed to update DNS record: $($response.errors | ConvertTo-Json)" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
            return $false
        }
    }
    catch {
        Write-CloudflareDDNSLog -Message "ERROR: Failed to update Cloudflare record: $_" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
        return $false
    }
} 