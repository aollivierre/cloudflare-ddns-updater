function Write-CloudflareDDNSLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Status = "INFO",
        
        [Parameter(Mandatory = $false)]
        [string]$Color = "White",
        
        [Parameter(Mandatory = $false)]
        [string]$LogFilePath = "",
        
        [Parameter(Mandatory = $false)]
        [switch]$Console = $false
    )
    
    # If no explicit log path is provided, use the global log file
    if ([string]::IsNullOrEmpty($LogFilePath)) {
        $LogFilePath = $script:LogFile
    }
    
    # Get identity for context-aware logging
    try {
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    } catch {
        $currentUser = "Unknown"
    }
    
    # Format the log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$currentUser] [$Status] $Message"
    
    # Write to the log file
    if (![string]::IsNullOrEmpty($LogFilePath)) {
        try {
            # Ensure the directory exists
            $logDir = Split-Path -Path $LogFilePath -Parent
            if (![string]::IsNullOrEmpty($logDir) -and !(Test-Path -Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            
            # Add the log entry
            $logEntry | Out-File -FilePath $LogFilePath -Append
        }
        catch {
            # If we can't write to the log, at least try to display the error
            Write-Error "Failed to write to log $LogFilePath. Error: $($_.Exception.Message)"
        }
    }
    
    # Output to console if requested
    if ($Console) {
        # Use appropriate color based on status
        $displayColor = $Color
        if ($Status -eq "SUCCESS") { $displayColor = "Green" }
        elseif ($Status -eq "ERROR") { $displayColor = "Red" }
        elseif ($Status -eq "WARNING") { $displayColor = "Yellow" }
        
        # Write the message (not the full log entry) to the console
        Write-Host $Message -ForegroundColor $displayColor
    }
} 