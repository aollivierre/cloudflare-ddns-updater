function Get-PublicIP {
    [CmdletBinding()]
    param()
    
    $ipServices = @(
        "https://api.ipify.org",
        "https://ifconfig.me/ip",
        "https://icanhazip.com",
        "https://wtfismyip.com/text",
        "https://api.ipify.org?format=text",
        "https://checkip.amazonaws.com"
    )
    
    foreach ($service in $ipServices) {
        try {
            $ip = Invoke-RestMethod -Uri $service -TimeoutSec 5
            if ($ip -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                Write-CloudflareDDNSLog -Message "Detected public IP $ip" -LogFilePath $script:LogFile
                return $ip.Trim()
            }
        }
        catch {
            # Continue to the next service
        }
    }
    
    # If all services fail, log the error
    Write-CloudflareDDNSLog -Message "ERROR: Failed to get public IP $_" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
    return $null
} 