#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Manages hosts file entry for RD Gateway based on network location
.DESCRIPTION
    This script manages the hosts file entry for the RD Gateway FQDN based on network location.
    
    Network Detection:
    - The script checks all network adapters for IP addresses matching the HomeNetworkPrefix pattern (e.g. 198.18.1.*)
    - If any matching interface is found, you are considered to be at home
    - If no matching interfaces are found, you are considered to be away
    
    Hosts File Handling:
    - When at home: Adds or uncomments the entry to point the Gateway FQDN to the internal IP
    - When away: Comments out the entry to allow DNS to resolve to the public IP
    - The script preserves the hosts file entry by commenting rather than deleting it
    
    The script can be run interactively or as a scheduled task with multiple triggers.
.EXAMPLE
    .\Manage-RDGatewayHosts.ps1
    Shows the interactive menu with all options
.EXAMPLE
    .\Manage-RDGatewayHosts.ps1 -Silent
    Runs silently (for scheduled tasks)
.EXAMPLE
    .\Manage-RDGatewayHosts.ps1 -InstallTask
    Installs the scheduled task with multiple triggers
#>

[CmdletBinding(DefaultParameterSetName = 'Operation')]
param(
    [Parameter(ParameterSetName = 'Operation')]
    [switch]$Silent,
    
    [Parameter(ParameterSetName = 'Install')]
    [switch]$InstallTask,
    
    [Parameter(ParameterSetName = 'Operation')]
    [switch]$ShowLog,
    
    # Fixed parameters for RD Gateway
    [Parameter(ParameterSetName = 'Operation')]
    [string]$GatewayFQDN = "rdgateway02.cloudcommand.org",
    
    [Parameter(ParameterSetName = 'Operation')]
    [string]$GatewayIP = "198.18.1.109",
    
    [Parameter(ParameterSetName = 'Operation')]
    [string]$HomeNetworkPrefix = "198.18.1",
    
    [Parameter(ParameterSetName = 'Operation')]
    [string]$LogFile = "$env:ProgramData\RDGatewayHosts\RDGatewayHosts.log"
)

#region Functions
function Write-RDGatewayLog {
    param(
        [string]$Message,
        [string]$Status = "INFO",
        [string]$Color = "White"
    )
    
    # Ensure log directory exists
    $logDir = Split-Path -Parent $LogFile
    if (-not (Test-Path $logDir)) {
        try {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        catch {
            # If we can't create the directory, fallback to temp
            $LogFile = "$env:TEMP\RDGatewayHosts.log"
            $logDir = Split-Path -Parent $LogFile
            
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    
    # Check log file size and implement rotation if needed
    if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt 100KB)) {
        # Create a timestamp for the backup log
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupLog = "$LogFile.$timestamp.bak"
        
        # Move current log to backup
        try {
            Copy-Item -Path $LogFile -Destination $backupLog -Force -ErrorAction SilentlyContinue
            "Log file rotation occurred at $(Get-Date)" | Set-Content -Path $LogFile -ErrorAction SilentlyContinue
        }
        catch {
            # Just continue if we can't rotate logs
        }
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Status] $Message"
    
    # Add to log file
    try {
        Add-Content -Path $LogFile -Value $logMessage -ErrorAction Stop
    }
    catch {
        # If we can't write to the log, try alternate location
        $tempLogFile = "$env:TEMP\RDGatewayHosts.emergency.log"
        $errorMsg = "[$timestamp] [ERROR] Failed to write to primary log. See error details on next line."
        $errorDetails = "[$timestamp] [ERROR] $($_.Exception.Message)"
        $logLocationMsg = "[$timestamp] [INFO] Using alternate log location $tempLogFile"
        Add-Content -Path $tempLogFile -Value $errorMsg -ErrorAction SilentlyContinue
        Add-Content -Path $tempLogFile -Value $errorDetails -ErrorAction SilentlyContinue
        Add-Content -Path $tempLogFile -Value $logLocationMsg -ErrorAction SilentlyContinue
        Add-Content -Path $tempLogFile -Value $logMessage -ErrorAction SilentlyContinue
    }
    
    # Output to console if not in silent mode
    if (-not $Silent) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Show-Menu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "    RD GATEWAY HOSTS MANAGER             " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " This tool helps manage RDP Gateway access" -ForegroundColor White
    Write-Host " by updating hosts file entries based on  " -ForegroundColor White
    Write-Host " whether you're at home or away.          " -ForegroundColor White
    Write-Host ""
    Write-Host " Select an option:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " 1: Run hosts file update now" -ForegroundColor Green
    Write-Host " 2: Install scheduled task" -ForegroundColor Green
    Write-Host " 3: View log file" -ForegroundColor Green
    Write-Host " 4: Clear log file" -ForegroundColor Green
    Write-Host " 5: View/Edit hosts file" -ForegroundColor Green
    Write-Host " Q: Quit" -ForegroundColor Green
    Write-Host ""
    
    $selection = Read-Host "Enter your choice (1-5 or Q)"
    
    switch ($selection.ToUpper()) {
        "1" { 
            Update-HostsFile
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            return $true
        }
        "2" { 
            Install-ScheduledTask
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            return $true
        }
        "3" { 
            Show-LogFile
            return $true
        }
        "4" { 
            Clear-LogFile
            return $true
        }
        "5" { 
            Open-HostsFile
            return $true
        }
        "Q" { return $false }
        default { 
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
            return $true
        }
    }
}

function Show-LogFile {
    $primaryLogFile = $LogFile
    $emergencyLogFile = "$env:TEMP\RDGatewayHosts.emergency.log"
    $logFound = $false
    
    Write-Host "Checking for log files..." -ForegroundColor Cyan
    
    # Check and display primary log
    if (Test-Path $primaryLogFile) {
        $logFound = $true
        Write-Host "Primary log file found at: $primaryLogFile" -ForegroundColor Green
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host ""
        
        # Get log file content with basic handling for large files
        $logContent = Get-Content -Path $primaryLogFile -Tail 50 -ErrorAction SilentlyContinue
        
        if ($logContent.Count -eq 50) {
            Write-Host "NOTE: Showing last 50 entries only. Full log at: $primaryLogFile" -ForegroundColor Yellow
            Write-Host ""
        }
        
        $logContent | ForEach-Object {
            if ($_ -match "\[ERROR\]") {
                Write-Host $_ -ForegroundColor Red
            } elseif ($_ -match "\[WARNING\]") {
                Write-Host $_ -ForegroundColor Yellow
            } else {
                Write-Host $_
            }
        }
    }
    
    # Check and display emergency log if it exists
    if (Test-Path $emergencyLogFile) {
        $logFound = $true
        Write-Host ""
        Write-Host "Emergency log file found at: $emergencyLogFile" -ForegroundColor Yellow
        Write-Host "This indicates there were problems writing to the primary log." -ForegroundColor Yellow
        Write-Host "=========================================" -ForegroundColor Cyan
        Write-Host ""
        
        $emergencyContent = Get-Content -Path $emergencyLogFile -Tail 20 -ErrorAction SilentlyContinue
        $emergencyContent | ForEach-Object {
            if ($_ -match "\[ERROR\]") {
                Write-Host $_ -ForegroundColor Red
            } elseif ($_ -match "\[WARNING\]") {
                Write-Host $_ -ForegroundColor Yellow
            } else {
                Write-Host $_
            }
        }
    }
    
    if (-not $logFound) {
        Write-Host "No log files found at: $primaryLogFile" -ForegroundColor Red
        Write-Host "or $emergencyLogFile" -ForegroundColor Red
        Write-Host ""
        Write-Host "The scheduled task might be using a different location." -ForegroundColor Yellow
        
        # Try to find any RDGatewayHosts log files in common locations
        $possibleLogFiles = @(
            "$env:ProgramData\RDGatewayHosts\*.log",
            "$env:TEMP\RDGatewayHosts*.log",
            "C:\Windows\Temp\RDGatewayHosts*.log"
        )
        
        $foundLogs = Get-ChildItem -Path $possibleLogFiles -ErrorAction SilentlyContinue
        
        if ($foundLogs) {
            Write-Host "Found possible log files:" -ForegroundColor Cyan
            foreach ($logFile in $foundLogs) {
                Write-Host "- $($logFile.FullName) (Last modified: $($logFile.LastWriteTime))" -ForegroundColor White
            }
            
            Write-Host ""
            $viewOther = Read-Host "Enter the full path of a log to view, or press Enter to cancel"
            
            if ($viewOther -and (Test-Path $viewOther)) {
                Write-Host ""
                Write-Host "Contents of $viewOther" -ForegroundColor Cyan
                Write-Host "=========================================" -ForegroundColor Cyan
                Write-Host ""
                
                $otherContent = Get-Content -Path $viewOther -Tail 50 -ErrorAction SilentlyContinue
                $otherContent | ForEach-Object {
                    if ($_ -match "\[ERROR\]") {
                        Write-Host $_ -ForegroundColor Red
                    } elseif ($_ -match "\[WARNING\]") {
                        Write-Host $_ -ForegroundColor Yellow
                    } else {
                        Write-Host $_
                    }
                }
            }
        }
    }
    
    Write-Host ""
    Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
    Read-Host
}

function Test-HomeNetwork {
    Write-RDGatewayLog "Checking if we're on the home network ($HomeNetworkPrefix.x)..." -Status "INFO" -Color "Cyan"
    
    # Get network interfaces with IPs in our target subnet
    $interfaces = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.IPAddress -like "$HomeNetworkPrefix.*" 
    }
    
    if ($interfaces) {
        foreach ($iface in $interfaces) {
            Write-RDGatewayLog "Found home network interface: $($iface.InterfaceAlias) with IP $($iface.IPAddress)" -Status "INFO" -Color "Green"
        }
        return $true
    } else {
        Write-RDGatewayLog "No interfaces found in the home network ($HomeNetworkPrefix.*)" -Status "INFO" -Color "Yellow"
        return $false
    }
}

function Get-HostsContent {
    param (
        [string]$FilePath = "$env:SystemRoot\System32\drivers\etc\hosts",
        [switch]$AsRaw
    )
    
    Write-RDGatewayLog "Reading hosts file content..." -Status "INFO" -Color "Cyan"
    
    # Try to read the file with retries
    $maxRetries = 3
    $retryDelay = 500 # milliseconds
    
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            if ($AsRaw) {
                $content = [System.IO.File]::ReadAllText($FilePath)
            } else {
                $content = [System.IO.File]::ReadAllLines($FilePath)
            }
            return $content
        }
        catch {
            if ($i -eq ($maxRetries - 1)) {
                Write-RDGatewayLog "Failed to read hosts file after $maxRetries attempts: $_" -Status "ERROR" -Color "Red"
                return $null
            }
            Write-RDGatewayLog "Retrying file read in $retryDelay ms..." -Status "WARNING" -Color "Yellow"
            Start-Sleep -Milliseconds $retryDelay
            $retryDelay *= 2 # Exponential backoff
        }
    }
}

function Set-HostsContent {
    param (
        [string]$Content,
        [string]$FilePath = "$env:SystemRoot\System32\drivers\etc\hosts"
    )
    
    Write-RDGatewayLog "Writing hosts file content..." -Status "INFO" -Color "Cyan"
    
    # Try to write the file with retries
    $maxRetries = 3
    $retryDelay = 500 # milliseconds
    
    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            [System.IO.File]::WriteAllText($FilePath, $Content)
            Write-RDGatewayLog "Hosts file updated successfully." -Status "INFO" -Color "Green"
            return $true
        }
        catch {
            if ($i -eq ($maxRetries - 1)) {
                Write-RDGatewayLog "Failed to write hosts file after $maxRetries attempts: $_" -Status "ERROR" -Color "Red"
                return $false
            }
            Write-RDGatewayLog "Retrying file write in $retryDelay ms..." -Status "WARNING" -Color "Yellow"
            Start-Sleep -Milliseconds $retryDelay
            $retryDelay *= 2 # Exponential backoff
        }
    }
}

function Find-LockedHostsFile {
    param (
        [string]$FilePath = "$env:SystemRoot\System32\drivers\etc\hosts",
        [switch]$Detailed
    )
    
    Write-RDGatewayLog "Checking if hosts file is locked..." -Status "INFO" -Color "Cyan"
    
    # Initialize result object
    $result = @{
        IsLocked = $false
        LockingProcesses = @()
    }
    
    # First try using Handle.exe if available or can be downloaded
    $handleExe = Get-HandleExe
    if ($handleExe) {
        Write-RDGatewayLog "Using Handle.exe to check for file locks" -Status "INFO" -Color "Cyan"
        $lockInfo = Get-FileLockInfoUsingHandle -FilePath $FilePath -HandleExePath $handleExe
        
        $result.IsLocked = $lockInfo.IsLocked
        $result.LockingProcesses = $lockInfo.LockingProcesses
        
        if ($lockInfo.IsLocked) {
            foreach ($process in $lockInfo.LockingProcesses) {
                Write-RDGatewayLog "File is locked by process: $($process.ProcessName) (PID: $($process.ProcessId))" -Status "WARNING" -Color "Yellow"
            }
        }
    }
    else {
        # Fallback to simple file stream check
        try {
            $fileStream = [System.IO.File]::Open($FilePath, 'Open', 'Write')
            $fileStream.Close()
            $fileStream.Dispose()
            Write-RDGatewayLog "Hosts file is not locked." -Status "INFO" -Color "Green"
            $result.IsLocked = $false
        }
        catch {
            Write-RDGatewayLog "Hosts file appears to be locked by another process." -Status "WARNING" -Color "Yellow"
            $result.IsLocked = $true
            
            # Try to identify common text editors that might have it open
            $knownHostsApps = @("notepad", "notepad++", "wordpad", "code")
            
            foreach ($appName in $knownHostsApps) {
                $processes = Get-Process -Name $appName -ErrorAction SilentlyContinue
                if ($processes) {
                    Write-RDGatewayLog "Found potential locking process: $appName" -Status "WARNING" -Color "Yellow"
                    foreach ($proc in $processes) {
                        $result.LockingProcesses += @{
                            ProcessName = $proc.Name
                            ProcessId = $proc.Id
                        }
                    }
                }
            }
        }
    }
    
    if ($Detailed) {
        return $result
    }
    else {
        return $result.IsLocked
    }
}

function Get-HandleExe {
    # Define the folder where Handle.exe will be stored
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $handleDir = Join-Path $env:TEMP "SysinternalsHandle_$timestamp"
    
    # Check if running on 64-bit system
    $is64Bit = [Environment]::Is64BitOperatingSystem
    $handleExeName = if ($is64Bit) { "handle64.exe" } else { "handle.exe" }
    $handleExePath = Join-Path $handleDir $handleExeName
    
    # Create directory if it doesn't exist
    if (-not (Test-Path $handleDir)) {
        try {
            New-Item -Path $handleDir -ItemType Directory -Force | Out-Null
            Write-RDGatewayLog "Created temporary directory for Handle.exe: $handleDir" -Status "INFO" -Color "Cyan"
        }
        catch {
            Write-RDGatewayLog "Failed to create directory for Handle.exe: $_" -Status "ERROR" -Color "Red"
            return $null
        }
    }
    
    # Download Handle.exe if not already present
    try {
        $handleUrl = "https://download.sysinternals.com/files/Handle.zip"
        $zipPath = Join-Path $handleDir "handle.zip"
        
        # Use .NET WebClient for the download
        $webClient = New-Object System.Net.WebClient
        Write-RDGatewayLog "Downloading Handle.exe from Sysinternals..." -Status "INFO" -Color "Cyan"
        $webClient.DownloadFile($handleUrl, $zipPath)
        
        # Extract the ZIP file
        Write-RDGatewayLog "Extracting Handle.exe..." -Status "INFO" -Color "Cyan"
        Expand-Archive -Path $zipPath -DestinationPath $handleDir -Force
        
        # Verify Handle.exe exists
        if (Test-Path $handleExePath) {
            Write-RDGatewayLog "Handle.exe ($handleExeName) successfully downloaded and extracted." -Status "INFO" -Color "Green"
            return $handleExePath
        }
        else {
            Write-RDGatewayLog "$handleExeName not found after extraction. Trying alternate version..." -Status "WARNING" -Color "Yellow"
            
            # Try the alternate version as fallback
            $fallbackExeName = if ($is64Bit) { "handle.exe" } else { "handle64.exe" }
            $fallbackPath = Join-Path $handleDir $fallbackExeName
            
            if (Test-Path $fallbackPath) {
                Write-RDGatewayLog "Using $fallbackExeName as fallback." -Status "INFO" -Color "Yellow"
                return $fallbackPath
            }
            
            Write-RDGatewayLog "No Handle.exe versions found after extraction." -Status "WARNING" -Color "Yellow"
            return $null
        }
    }
    catch {
        Write-RDGatewayLog "Failed to download or extract Handle.exe: $_" -Status "ERROR" -Color "Red"
        return $null
    }
}

function Get-FileLockInfoUsingHandle {
    param (
        [string]$FilePath,
        [string]$HandleExePath
    )
    
    $result = @{
        IsLocked = $false
        LockingProcesses = @()
    }
    
    try {
        # Run Handle.exe to check file locks with a timeout
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $HandleExePath
        $processStartInfo.Arguments = "-nobanner -accepteula `"$FilePath`""
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.CreateNoWindow = $true
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        
        Write-RDGatewayLog "Starting Handle.exe to check for locks..." -Status "INFO" -Color "Cyan"
        [void]$process.Start()
        
        # Wait for process to complete with a timeout
        $timeoutSeconds = 10
        if (-not $process.WaitForExit($timeoutSeconds * 1000)) {
            Write-RDGatewayLog "Handle.exe is taking too long. Terminating process." -Status "WARNING" -Color "Yellow"
            try {
                $process.Kill()
            } catch {
                Write-RDGatewayLog "Could not terminate Handle.exe process: $_" -Status "ERROR" -Color "Red"
            }
            return $result
        }
        
        # Read the output
        $output = $process.StandardOutput.ReadToEnd() -split "`r`n"
        $errorOutput = $process.StandardError.ReadToEnd()
        
        if ($errorOutput) {
            Write-RDGatewayLog "Handle.exe error: $errorOutput" -Status "ERROR" -Color "Red"
        }
        
        # Process the output to extract locking processes
        $processes = @()
        
        foreach ($line in $output) {
            if ($line -match "pid:\s+(\d+)\s+(.+)") {
                $processId = $matches[1]
                $processName = $matches[2].Trim()
                
                $processes += @{
                    ProcessId = $processId
                    ProcessName = $processName
                }
            }
        }
        
        if ($processes.Count -gt 0) {
            $result.IsLocked = $true
            $result.LockingProcesses = $processes
            
            # Log processes found
            Write-RDGatewayLog "Found $($processes.Count) processes locking the file" -Status "INFO" -Color "Yellow"
        } else {
            Write-RDGatewayLog "No processes found locking the file" -Status "INFO" -Color "Green"
        }
    }
    catch {
        Write-RDGatewayLog "Error using Handle.exe: $_" -Status "ERROR" -Color "Red"
    }
    
    return $result
}

function Update-HostsFile {
    Write-RDGatewayLog "RD Gateway Hosts Entry Manager started" -Status "INFO" -Color "Green"
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    
    # Check if hosts file is locked - just for logging, we'll try anyway
    $isLocked = Find-LockedHostsFile
    
    # Check if we're on the home network
    $onHomeNetwork = Test-HomeNetwork
    
    # Read hosts file content with retry mechanism
    $hostsContent = Get-HostsContent -FilePath $hostsFile -AsRaw
    
    # If we couldn't read the file, abort
    if ([string]::IsNullOrEmpty($hostsContent)) {
        Write-RDGatewayLog "Could not read hosts file. Aborting." -Status "ERROR" -Color "Red"
        return
    }
    
    # Ensure file ends with newline
    if (-not $hostsContent.EndsWith("`n")) {
        $hostsContent += "`r`n" # Ensure the file ends with a newline
    }
    
    # Split content into lines for processing
    $hostsLines = $hostsContent -split "`r`n"
    $entryPattern = "\s+$GatewayFQDN"
    $gatewayLineIndex = -1
    
    # Find if entry exists and its index (uncommented)
    for ($i = 0; $i -lt $hostsLines.Count; $i++) {
        if ($hostsLines[$i] -match $entryPattern -and $hostsLines[$i] -notmatch '^\s*#') {
            $gatewayLineIndex = $i
            break
        }
    }
    
    # Also check for commented entry
    $commentedGatewayLineIndex = -1
    for ($i = 0; $i -lt $hostsLines.Count; $i++) {
        if ($hostsLines[$i] -match $entryPattern -and $hostsLines[$i] -match '^\s*#') {
            $commentedGatewayLineIndex = $i
            break
        }
    }
    
    $contentUpdated = $false
    
    if ($onHomeNetwork) {
        # When on home network, add/update the hosts entry
        Write-RDGatewayLog "On home network. Ensuring hosts entry exists for $GatewayFQDN -> $GatewayIP" -Status "INFO" -Color "Green"
        
        $newEntry = "$GatewayIP    $GatewayFQDN"
        
        if ($gatewayLineIndex -ge 0) {
            # Entry exists, check if correct
            if ($hostsLines[$gatewayLineIndex] -notmatch "^$GatewayIP\s+$GatewayFQDN") {
                # Update existing entry
                Write-RDGatewayLog "Updating entry for $GatewayFQDN with IP $GatewayIP" -Status "WARNING" -Color "Yellow"
                $hostsLines[$gatewayLineIndex] = $newEntry
                $contentUpdated = $true
            } else {
                Write-RDGatewayLog "Hosts file entry already exists with correct IP ($GatewayIP)." -Status "INFO" -Color "Green"
            }
        } 
        elseif ($commentedGatewayLineIndex -ge 0) {
            # Commented entry exists, uncomment it
            Write-RDGatewayLog "Uncommenting and updating entry for $GatewayFQDN" -Status "WARNING" -Color "Yellow"
            $hostsLines[$commentedGatewayLineIndex] = $newEntry
            $contentUpdated = $true
        }
        else {
            # No entry exists, add new entry
            Write-RDGatewayLog "Adding new entry: $newEntry" -Status "WARNING" -Color "Yellow"
            $hostsLines += $newEntry
            $contentUpdated = $true
        }
    } else {
        # When away from home network, comment the entry if it exists
        Write-RDGatewayLog "Not on home network. Commenting hosts entry if it exists." -Status "INFO" -Color "Yellow"
        
        if ($gatewayLineIndex -ge 0) {
            Write-RDGatewayLog "Commenting hosts file entry for $GatewayFQDN" -Status "WARNING" -Color "Yellow"
            # Ensure consistent comment format with space after #
            $hostsLines[$gatewayLineIndex] = "# " + $hostsLines[$gatewayLineIndex].TrimStart()
            Write-RDGatewayLog "Entry commented. When away, $GatewayFQDN will resolve via corporate DNS." -Status "INFO" -Color "Green"
            $contentUpdated = $true
        } 
        elseif ($commentedGatewayLineIndex -ge 0) {
            Write-RDGatewayLog "Hosts file entry already commented. No action needed." -Status "INFO" -Color "Green"
        }
        else {
            Write-RDGatewayLog "No hosts file entry exists. No action needed." -Status "INFO" -Color "Green"
        }
    }
    
    # Only write back if changes were made
    if ($contentUpdated) {
        # Write hosts file content back preserving structure
        $modifiedContent = $hostsLines -join "`r`n"
        $writeSuccess = Set-HostsContent -Content $modifiedContent -FilePath $hostsFile
        
        if (-not $writeSuccess) {
            Write-RDGatewayLog "Failed to update hosts file. Check permissions and try again." -Status "ERROR" -Color "Red"
            return
        }
    } else {
        Write-RDGatewayLog "No changes needed to hosts file." -Status "INFO" -Color "Green"
    }
    
    # Flush DNS cache
    try {
        ipconfig /flushdns | Out-Null
        Write-RDGatewayLog "DNS cache flushed." -Status "INFO" -Color "Cyan"
    }
    catch {
        Write-RDGatewayLog "Failed to flush DNS cache: $_" -Status "WARNING" -Color "Yellow"
    }
    
    # Test the DNS resolution
    try {
        $resolvedIP = [System.Net.Dns]::GetHostAddresses($GatewayFQDN) | 
            Where-Object { $_.AddressFamily -eq 'InterNetwork' } | 
            Select-Object -ExpandProperty IPAddressToString -First 1
            
        if ($onHomeNetwork) {
            if ($resolvedIP -eq $GatewayIP) {
                Write-RDGatewayLog "Success! $GatewayFQDN resolves to internal IP $resolvedIP" -Status "INFO" -Color "Green"
            } else {
                Write-RDGatewayLog "Warning: $GatewayFQDN resolves to $resolvedIP instead of $GatewayIP" -Status "WARNING" -Color "Yellow"
            }
        } else {
            Write-RDGatewayLog "When away, $GatewayFQDN resolves to $resolvedIP" -Status "INFO" -Color "Green"
        }
    } catch {
        Write-RDGatewayLog "Error testing DNS resolution: $_" -Status "ERROR" -Color "Red"
    }
    
    Write-RDGatewayLog "RD Gateway Hosts Entry Manager completed" -Status "INFO" -Color "Green"
}

function Install-ScheduledTask {
    Write-Host "Setting up scheduled task for RD Gateway Hosts Manager..." -ForegroundColor Cyan
    Write-Host ""
    
    try {
        # Get the current script path using a more reliable method
        $scriptPath = $PSCommandPath
        if (-not $scriptPath) {
            $scriptPath = $MyInvocation.MyCommand.Definition
        }
        if (-not $scriptPath) {
            $scriptPath = Get-Item -Path ".\$($MyInvocation.MyCommand.Name)" | Select-Object -ExpandProperty FullName
        }
        
        if (-not (Test-Path $scriptPath)) {
            throw "Could not determine script path. Please run this script directly."
        }
        
        Write-Host "Using script path: $scriptPath" -ForegroundColor Cyan
        
        # Delete existing task if it exists
        Unregister-ScheduledTask -TaskName "RD Gateway Hosts Manager" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        
        # Get the current time for StartBoundary
        $startBoundary = (Get-Date).AddMinutes(1).ToString("yyyy-MM-ddTHH:mm:ss.000") + (Get-Date).ToString("zzz")
        
        # Create the XML task definition
        $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\RD Gateway Hosts Manager</URI>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <TimeTrigger>
      <Repetition>
        <Interval>PT15M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$startBoundary</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
    <BootTrigger>
      <Enabled>true</Enabled>
      <Delay>PT1M</Delay>
    </BootTrigger>
    <TimeTrigger>
      <Repetition>
        <Interval>PT1M</Interval>
        <StopAtDurationEnd>false</StopAtDurationEnd>
      </Repetition>
      <StartBoundary>$startBoundary</StartBoundary>
      <Enabled>true</Enabled>
    </TimeTrigger>
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
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
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
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$scriptPath" -Silent -LogFile "$env:ProgramData\RDGatewayHosts\RDGatewayHosts.log"</Arguments>
    </Exec>
  </Actions>
</Task>
"@
        
        # Register the task using the XML definition
        Register-ScheduledTask -TaskName "RD Gateway Hosts Manager" -Xml $taskXml -Force | Out-Null
        
        Write-Host "Scheduled task has been successfully created!" -ForegroundColor Green
        Write-Host ""
        Write-Host "The task will run:" -ForegroundColor Yellow
        Write-Host "- At user logon" -ForegroundColor Yellow
        Write-Host "- Every minute (for quick network change detection)" -ForegroundColor Yellow
        Write-Host "- Every 15 minutes (regular check)" -ForegroundColor Yellow
        Write-Host "- At startup (after a 1-minute delay)" -ForegroundColor Yellow
        Write-Host "- When network profile changes (EventID 10000/10001)" -ForegroundColor Yellow
        Write-Host "- When network adapter disconnects (EventID 4202)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This ensures your hosts file is always properly configured" -ForegroundColor Yellow
        Write-Host "based on whether you're at home or away." -ForegroundColor Yellow
    }
    catch {
        Write-Host "Error creating scheduled task: $_" -ForegroundColor Red
    }
}

function Clear-LogFile {
    Write-Host "Clearing log file..." -ForegroundColor Yellow
    
    # Check if log file exists
    if (Test-Path $LogFile) {
        try {
            # Create timestamp
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            # Backup old log before clearing
            $backupFile = "$LogFile.old"
            Copy-Item -Path $LogFile -Destination $backupFile -Force
            
            # Create fresh log with header
            "[${timestamp}] [SYSTEM] Log file cleared. Previous log saved to: $backupFile" | Set-Content -Path $LogFile
            Write-Host "Log file has been cleared. Previous logs backed up to: $backupFile" -ForegroundColor Green
        }
        catch {
            Write-Host "Error clearing log file: $_" -ForegroundColor Red
        }
    }
    else {
        # If no log file exists, create a new one
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[${timestamp}] [SYSTEM] New log file initialized." | Set-Content -Path $LogFile
        Write-Host "No log file found. Created a new log file." -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
    Read-Host
}

# Make sure the log file is initialized at startup
function Initialize-LogFile {
    # Make sure log directory exists
    $logDir = Split-Path -Parent $LogFile
    if (-not (Test-Path $logDir)) {
        try {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            Write-Host "Created log directory: $logDir" -ForegroundColor Green
        }
        catch {
            Write-Host "Could not create log directory $logDir. Using $env:TEMP instead." -ForegroundColor Yellow
            $LogFile = "$env:TEMP\RDGatewayHosts.log"
        }
    }
    
    # If the log file doesn't exist or is very old (>7 days), create a new one
    if (-not (Test-Path $LogFile) -or 
        ((Get-Item $LogFile).LastWriteTime -lt (Get-Date).AddDays(-7))) {
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        try {
            "[${timestamp}] [SYSTEM] Log file initialized." | Set-Content -Path $LogFile
            Write-Host "Log file initialized: $LogFile" -ForegroundColor Green
        }
        catch {
            Write-Host "Could not initialize log file at $LogFile. Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Add new function to open the hosts file in Notepad
function Open-HostsFile {
    $hostsFile = "$env:SystemRoot\System32\drivers\etc\hosts"
    Write-Host "Opening hosts file with Notepad..." -ForegroundColor Cyan
    
    # Check if file exists
    if (-not (Test-Path $hostsFile)) {
        Write-Host "Hosts file not found at: $hostsFile" -ForegroundColor Red
        Write-Host ""
        Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
        Read-Host
        return
    }
    
    # Check for processes that might be locking the file
    $lockInfo = Find-LockedHostsFile -Detailed
    
    if ($lockInfo.IsLocked) {
        Write-Host "WARNING: Hosts file may be locked by the following processes:" -ForegroundColor Yellow
        foreach ($process in $lockInfo.LockingProcesses) {
            Write-Host "  - Process: $($process.ProcessName) (PID: $($process.ProcessId))" -ForegroundColor Yellow
        }
        Write-Host "Opening the file in read-only mode may be safer." -ForegroundColor Yellow
        Write-Host ""
        
        $prompt = Read-Host "Do you want to continue opening the file? (Y/N)"
        if ($prompt.ToUpper() -ne "Y") {
            Write-Host "Operation cancelled." -ForegroundColor Red
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            return
        }
    }
    
    # Open the file in Notepad
    try {
        # Use cmd /c to launch notepad in a separate process without waiting
        $notepadProcess = Start-Process -FilePath "notepad.exe" -ArgumentList $hostsFile -PassThru
        
        # Wait for the process to exit with timeout
        $timeoutSeconds = 3600  # 1 hour timeout
        $startTime = Get-Date
        
        Write-Host "Waiting for Notepad to close..." -ForegroundColor Cyan
        
        # Wait for the process to exit or timeout
        while (-not $notepadProcess.HasExited -and ((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds) {
            Start-Sleep -Seconds 1
        }
        
        # Check if we exited due to timeout
        if (-not $notepadProcess.HasExited) {
            Write-Host "Notepad is still open. Continuing..." -ForegroundColor Yellow
        } else {
            Write-Host "Hosts file has been opened and closed." -ForegroundColor Green
        }
        
        # Ask if user wants to flush DNS after editing
        $flushDns = Read-Host "Would you like to flush the DNS cache? (Y/N)"
        if ($flushDns.ToUpper() -eq "Y") {
            try {
                ipconfig /flushdns | Out-Null
                Write-Host "DNS cache flushed successfully." -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to flush DNS cache: $_" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "Error opening hosts file: $_" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
    Read-Host
}

#region Main execution
# Check for administrator privileges if modifying hosts file
if ((-not $ShowLog) -and (-not $InstallTask) -and (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))) {
    Write-RDGatewayLog "Administrator privileges required to modify hosts file." -Status "ERROR" -Color "Red"
    if (-not $Silent) {
        Write-Host "Please run the script with administrative privileges." -ForegroundColor Red
        exit 1
    }
}

# Initialize log file at startup
Initialize-LogFile

# Handle different execution modes
if ($InstallTask) {
    Install-ScheduledTask
    exit 0
}
elseif ($ShowLog) {
    Show-LogFile
    exit 0
}
elseif ($Silent) {
    Update-HostsFile
    exit 0
}
else {
    # Interactive mode - show menu
    $continueRunning = $true
    while ($continueRunning) {
        $continueRunning = Show-Menu
    }
}
#endregion
