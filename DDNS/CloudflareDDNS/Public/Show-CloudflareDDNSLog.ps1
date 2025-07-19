function Show-CloudflareDDNSLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$LogFilePath = ""
    )
    
    # Use the global log file path if none provided
    if ([string]::IsNullOrEmpty($LogFilePath)) {
        $LogFilePath = $script:LogFile
    }
    
    # Verify log file exists
    if (Test-Path -Path $LogFilePath) {
        Write-Host "Log file found at: $LogFilePath" -ForegroundColor Green
        
        # Display log content with color coding
        Get-Content -Path $LogFilePath | ForEach-Object {
            $line = $_
            Write-Host ($line | Out-String).TrimEnd()
        }
    } else {
        Write-Host "No log file found at: $LogFilePath" -ForegroundColor Yellow
    }
} 