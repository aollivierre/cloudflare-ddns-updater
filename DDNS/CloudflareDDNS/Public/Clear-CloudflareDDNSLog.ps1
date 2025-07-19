function Clear-CloudflareDDNSLog {
    [CmdletBinding()]
    param()
    
    if (Test-Path -Path $script:LogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        
        # Create backup of the log file
        $backupFile = "$script:LogFile.old"
        try {
            Copy-Item -Path $script:LogFile -Destination $backupFile -Force
            "[{0}] [{1}] Log file cleared. Previous log saved to: {2}" -f $timestamp, $userName, $backupFile | Set-Content -Path $script:LogFile
            Write-Host "Log file cleared and backed up to: $backupFile" -ForegroundColor Green
        } catch {
            Write-Host "Error clearing log file: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Log file does not exist: $script:LogFile" -ForegroundColor Yellow
    }
} 