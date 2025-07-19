# Check-KeepAwakeLog.ps1
# This script helps locate and display log files for the KeepAwake script

function Find-LogFiles {
    [CmdletBinding()]
    param()
    
    $logFiles = @()
    $foundPaths = @()
    $accessDeniedPaths = @()
    
    # Get the current username
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Debug "Current user: $currentUser"
    
    # Try to get all Windows users profiles to check their logs
    $userProfiles = @()
    try {
        $userProfilesDir = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList")."ProfilesDirectory"
        $userProfiles = Get-ChildItem -Path $userProfilesDir -Directory -ErrorAction SilentlyContinue | 
                         Where-Object { $_.Name -notlike "*systemprofile*" -and $_.Name -notlike "*LocalService*" -and $_.Name -notlike "*NetworkService*" }
        Write-Debug "Found $($userProfiles.Count) user profiles"
    } catch {
        Write-Debug "Failed to get user profiles: $_"
    }
    
    # Just check the likely locations without relying on script path
    $commonLocations = @(
        # Current directory
        (Join-Path -Path (Get-Location) -ChildPath "KeepAwake.log")
        # Code directory from the user's example
        "C:\code\KeepAwake\KeepAwake.log"
        # User profile
        (Join-Path -Path $env:USERPROFILE -ChildPath "KeepAwake.log")
        # User temp directory
        (Join-Path -Path $env:TEMP -ChildPath "KeepAwake.log")
        # System temp directory
        "C:\Windows\Temp\KeepAwakeSystem.log"
        # AppData
        (Join-Path -Path $env:APPDATA -ChildPath "KeepAwake.log")
    )
    
    Write-Debug "Checking common locations:"
    foreach ($loc in $commonLocations) {
        Write-Debug "  $loc"
    }
    
    # Add paths for all user profiles
    foreach ($profile in $userProfiles) {
        $commonLocations += (Join-Path -Path $profile.FullName -ChildPath "KeepAwake.log")
    }
    
    # Check all common locations
    foreach ($location in $commonLocations) {
        try {
            Write-Debug "Checking location: $location"
            if (Test-Path -Path $location -ErrorAction Stop) {
                Write-Debug "Found file at: $location"
                if ($foundPaths -notcontains $location) {
                    Write-Debug "Adding to found paths: $location"
                    $foundPaths += $location
                    
                    $logType = switch -Wildcard ($location) {
                        "*Windows\Temp*" { "System temp directory log" }
                        "*\Users\*" { 
                            $userName = $location -replace '.*\\Users\\([^\\]+)\\.*', '$1'
                            "User profile log ($userName)"
                        }
                        "*\$env:TEMP*" { "User temp directory log" }
                        "*\$env:APPDATA*" { "AppData log" }
                        "*C:\code\KeepAwake*" { "Script directory log" }
                        default { "Other location log" }
                    }
                    
                    Write-Debug "Creating log file object for: $location"
                    $logFile = [PSCustomObject]@{
                        Path = $location
                        Type = $logType
                        LastWriteTime = (Get-Item $location).LastWriteTime
                        IsCurrentUser = $logType -like "*$($env:USERNAME)*"
                    }
                    Write-Debug "Created log file object: $($logFile | ConvertTo-Json)"
                    $logFiles += $logFile
                    Write-Debug "Added log file to array. Current count: $($logFiles.Count)"
                } else {
                    Write-Debug "Location already in found paths: $location"
                }
            } else {
                Write-Debug "File not found at: $location"
            }
        }
        catch [System.UnauthorizedAccessException] {
            Write-Debug "Access denied to: $location"
            $accessDeniedPaths += $location
        }
        catch {
            Write-Debug "Error checking $location : $_"
        }
    }
    
    Write-Debug "Final log files count: $($logFiles.Count)"
    Write-Debug "Final access denied paths count: $($accessDeniedPaths.Count)"
    
    # Return both the log files and access denied paths
    return @{
        LogFiles = $logFiles
        AccessDeniedPaths = $accessDeniedPaths
        CurrentUser = $currentUser
    }
}

function Test-ProcessIsKeepAwake {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [System.Diagnostics.Process]$Process
    )
    
    Write-Debug "Checking process: $($Process.Id) - $($Process.ProcessName)"
    
    # Method 1: Check command line (works in PS7)
    try {
        Write-Debug "Attempting to check command line for process $($Process.Id)"
        if ($Process.CommandLine -like "*KeepAwake.ps1*" -or $Process.CommandLine -like "*KeepAwakeSystem.ps1*") {
            Write-Debug "Found KeepAwake in command line for process $($Process.Id)"
            return $true
        }
    } catch {
        Write-Debug "Failed to check command line for process $($Process.Id): $_"
    }
    
    # Method 2: Check process name and path (works in PS5)
    try {
        Write-Debug "Attempting to check process path for process $($Process.Id)"
        $processPath = $Process.Path
        if ($processPath -like "*powershell*" -or $processPath -like "*pwsh*") {
            Write-Debug "Found PowerShell process at path: $processPath"
            # Check if the process has a log file that's been modified recently
            $possibleLogs = @(
                (Join-Path -Path $env:USERPROFILE -ChildPath "KeepAwake.log"),
                (Join-Path -Path $env:TEMP -ChildPath "KeepAwake.log")
            )
            
            foreach ($log in $possibleLogs) {
                try {
                    Write-Debug "Checking log file: $log"
                    if (Test-Path -Path $log -ErrorAction Stop) {
                        $logFile = Get-Item -Path $log -ErrorAction Stop
                        Write-Debug "Found log file, last modified: $($logFile.LastWriteTime)"
                        # If the log was modified in the last 5 minutes, it's likely our process
                        if ($logFile.LastWriteTime -gt (Get-Date).AddMinutes(-5)) {
                            Write-Debug "Log file was modified recently, likely our process"
                            return $true
                        }
                    }
                } catch {
                    Write-Debug "Failed to check log file $log : $_"
                }
            }
        }
    } catch {
        Write-Debug "Failed to check process path for process $($Process.Id): $_"
    }
    
    # Method 3: Check for active power requests (requires admin)
    try {
        Write-Debug "Checking power requests"
        if ($isAdmin) {
            $powerRequests = powercfg /requests
            if ($powerRequests -notmatch "None.") {
                Write-Debug "Found active power requests"
                return $true
            }
        } else {
            Write-Debug "Skipping power request check - requires admin privileges"
        }
    } catch {
        Write-Debug "Failed to check power requests: $_"
    }
    
    # Method 4: Check if process is running under current user using WMI
    try {
        Write-Debug "Attempting to check process owner for process $($Process.Id)"
        
        # Use Get-CimInstance for PS7 compatibility
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $processInfo = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $($Process.Id)" -ErrorAction Stop
            if ($processInfo) {
                $owner = Invoke-CimMethod -InputObject $processInfo -MethodName GetOwner -ErrorAction Stop
                $processUser = $owner.User
                $currentUser = $env:USERNAME
                Write-Debug "Process owner: $processUser, Current user: $currentUser"
                if ($processUser -eq $currentUser) {
                    Write-Debug "Process is running under current user"
                    return $true
                }
            }
        } 
        else {
            # Original WMI approach for PS5.1
            $processInfo = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $($Process.Id)" -ErrorAction Stop
            if ($processInfo) {
                $processUser = $processInfo.GetOwner().User
                $currentUser = $env:USERNAME
                Write-Debug "Process owner: $processUser, Current user: $currentUser"
                if ($processUser -eq $currentUser) {
                    Write-Debug "Process is running under current user"
                    return $true
                }
            }
        }
    } catch {
        Write-Debug "Failed to check process owner for process $($Process.Id): $_"
    }
    
    Write-Debug "No KeepAwake indicators found for process $($Process.Id)"
    return $false
}

function Check-KeepAwakeTask {
    $taskName = "KeepAwakeTask"
    Write-Debug "Checking scheduled task: $taskName"
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    $taskInfo = @{
        TaskFound = $false
        TaskState = $null
        LastRunTime = $null
        LastResult = $null
        IsRunning = $false
        RunningPIDs = @()
        TaskUsername = $null
        PowerStatus = $null
        CurrentUsername = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
    
    if ($task) {
        Write-Debug "Found scheduled task"
        $taskInfo.TaskFound = $true
        $taskInfo.TaskState = $task.State
        $taskInfo.LastRunTime = $task.LastRunTime
        $taskInfo.LastResult = $task.LastTaskResult
        
        # Try to get principal info
        try {
            Write-Debug "Attempting to get task principal info"
            $taskInfo.TaskUsername = $task.Principal.UserId
            Write-Debug "Task username: $($taskInfo.TaskUsername)"
        }
        catch {
            Write-Debug "Failed to get task principal info: $_"
        }
        
        Write-Host "`nKeepAwakeTask Status" -ForegroundColor Green
        Write-Host "===================" -ForegroundColor Green
        Write-Host "Task Name       : $($task.TaskName)" -ForegroundColor White
        Write-Host "Status          : $($task.State)" -ForegroundColor White
        Write-Host "Last Run Time   : $($task.LastRunTime)" -ForegroundColor White
        Write-Host "Last Result     : $($task.LastTaskResult)" -ForegroundColor White
        
        if ($taskInfo.TaskUsername) {
            Write-Host "Runs As         : $($taskInfo.TaskUsername)" -ForegroundColor Cyan
            
            # Check if task is running under a different user than current
            if ($taskInfo.TaskUsername -ne $taskInfo.CurrentUsername -and $taskInfo.CurrentUsername -notlike "*$($taskInfo.TaskUsername)*") {
                Write-Host "WARNING: You're currently running as $($taskInfo.CurrentUsername) but the task runs as $($taskInfo.TaskUsername)" -ForegroundColor Yellow
                Write-Host "         This may limit your ability to see log files or process details." -ForegroundColor Yellow
            }
        }
        
        # Check if it's currently running using multiple detection methods
        try {
            Write-Debug "Getting PowerShell processes"
            $powershellProcesses = Get-Process -Name powershell*, pwsh* -ErrorAction SilentlyContinue
            Write-Debug "Found $($powershellProcesses.Count) PowerShell processes"
            
            $keepAwakeProcesses = @()
            
            foreach ($process in $powershellProcesses) {
                try {
                    Write-Debug "Checking process: $($process.Id)"
                    if (Test-ProcessIsKeepAwake -Process $process) {
                        Write-Debug "Found KeepAwake process: $($process.Id)"
                        $keepAwakeProcesses += $process
                    }
                } catch {
                    Write-Debug "Failed to check process $($process.Id): $_"
                }
            }
            
            if ($keepAwakeProcesses.Count -gt 0) {
                $taskInfo.IsRunning = $true
                $taskInfo.RunningPIDs = $keepAwakeProcesses.Id
                
                Write-Host "Process Status  : Running (PID: $($keepAwakeProcesses.Id -join ', '))" -ForegroundColor Green
                
                # Add check for sleep prevention
                try {
                    Write-Debug "Checking power requests"
                    $powerRequests = powercfg /requests
                    if ($powerRequests -match "None.") {
                        Write-Host "Power Status    : No active power requests - KeepAwake might not be working correctly" -ForegroundColor Yellow
                        $taskInfo.PowerStatus = "NoRequests"
                    } else {
                        Write-Host "Power Status    : Active power requests found - system should stay awake" -ForegroundColor Green
                        $taskInfo.PowerStatus = "ActiveRequests"
                    }
                } catch {
                    Write-Debug "Failed to check power requests: $_"
                    Write-Host "Power Status    : Unable to check power requests - run as administrator to check" -ForegroundColor Yellow
                    $taskInfo.PowerStatus = "Unknown"
                }
            } else {
                Write-Host "Process Status  : Not detected as running" -ForegroundColor Yellow
                Write-Host "Note: This could be due to permission limitations. Try running as administrator for more accurate detection." -ForegroundColor Yellow
                $restart = Read-Host "Would you like to restart the KeepAwake task? (Y/N)"
                if ($restart -eq 'Y' -or $restart -eq 'y') {
                    try {
                        Write-Host "Stopping task if running..." -ForegroundColor Cyan
                        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
                        
                        Write-Host "Starting task..." -ForegroundColor Cyan
                        Start-ScheduledTask -TaskName $taskName
                        
                        Write-Host "Task restarted successfully. Check the log file for new entries." -ForegroundColor Green
                    } catch {
                        Write-Host "Failed to restart task: $_" -ForegroundColor Red
                    }
                }
            }
        } catch {
            Write-Debug "Failed to check process status: $_"
            Write-Host "Process Status  : Unable to check process status - run as administrator to check" -ForegroundColor Yellow
            Write-Host "Note: This is normal when running without administrator privileges." -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nKeepAwakeTask is not found in scheduled tasks." -ForegroundColor Red
    }
    
    return $taskInfo
}

# Add a function to manually run the KeepAwake script
function Start-KeepAwakeManually {
    $scriptDir = "C:\code\KeepAwake"
    $keepAwakeScriptPath = Join-Path -Path $scriptDir -ChildPath "KeepAwake.ps1"
    
    if (Test-Path -Path $keepAwakeScriptPath) {
        Write-Host "`nStarting KeepAwake script manually..." -ForegroundColor Cyan
        try {
            Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$keepAwakeScriptPath`"" -WindowStyle Normal
            Write-Host "Script started successfully!" -ForegroundColor Green
        } catch {
            Write-Host "Failed to start script: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "`nCould not find KeepAwake.ps1 at expected location: $keepAwakeScriptPath" -ForegroundColor Red
        
        $newPath = Read-Host "Enter the full path to KeepAwake.ps1"
        if (Test-Path -Path $newPath) {
            try {
                Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$newPath`"" -WindowStyle Normal
                Write-Host "Script started successfully!" -ForegroundColor Green
            } catch {
                Write-Host "Failed to start script: $_" -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid path. Script not started." -ForegroundColor Red
        }
    }
}

# Main script execution
Clear-Host
Write-Host "KeepAwake Log Checker" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host "Running as: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)" -ForegroundColor White

# Enable debug output
$DebugPreference = "Continue"

# Check for admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Host "Running with administrator privileges." -ForegroundColor Green
} else {
    Write-Host "Running without administrator privileges. Some features may be limited." -ForegroundColor Yellow
    Write-Host "Note: Power request checks and some log file access will be limited." -ForegroundColor Yellow
}

# Check for the task status
$taskInfo = Check-KeepAwakeTask

# Find all potential log files
Write-Host "`nSearching for KeepAwake log files..." -ForegroundColor Cyan
$result = Find-LogFiles
$logFiles = $result.LogFiles
$accessDeniedPaths = $result.AccessDeniedPaths

# Warning about access denied paths
if ($accessDeniedPaths.Count -gt 0) {
    Write-Host "`nWARNING: Access denied to some potential log locations:" -ForegroundColor Yellow
    foreach ($path in $accessDeniedPaths) {
        Write-Host "  $path" -ForegroundColor Yellow
    }
    Write-Host "Try running as administrator to access these log files, or check logs in your own user profile." -ForegroundColor Yellow
}

# Smart suggestion for multi-user scenario
if ($taskInfo.TaskFound -and $taskInfo.TaskUsername -and $taskInfo.TaskUsername -ne $taskInfo.CurrentUsername) {
    Write-Host "`nIMPORTANT" -ForegroundColor Magenta
    Write-Host "The KeepAwake task runs as: $($taskInfo.TaskUsername)" -ForegroundColor Magenta
    Write-Host "You're checking logs as: $($taskInfo.CurrentUsername)" -ForegroundColor Magenta
    Write-Host "For best results, log in as $($taskInfo.TaskUsername) and run this script again." -ForegroundColor Magenta
}

# Convert logFiles to array and ensure proper handling
# Original code that doesn't work in PS5.1
# $logFilesArray = @()
# if ($null -ne $logFiles) {
#     $logFilesArray = @($logFiles)
# }

# Fixed version using ArrayList for PS5.1 compatibility
$logFilesArray = [System.Collections.ArrayList]::new()
if ($null -ne $logFiles) {
    foreach ($item in $logFiles) {
        [void]$logFilesArray.Add($item)
    }
}

if ($logFilesArray.Count -eq 0) {
    Write-Host "`nNo log files found. This could mean:" -ForegroundColor Yellow
    Write-Host "1. The script hasn't run yet" -ForegroundColor Yellow
    Write-Host "2. The script ran but didn't create logs" -ForegroundColor Yellow
    Write-Host "3. The logs are in a non-standard location or you don't have permission to access them" -ForegroundColor Yellow
    
    Write-Host "`nTips:" -ForegroundColor Cyan
    Write-Host "- Log out and log back in to trigger the task" -ForegroundColor White
    Write-Host "- Check if the task is configured correctly" -ForegroundColor White
    Write-Host "- Try running this script as the same user that runs the task: $($taskInfo.TaskUsername)" -ForegroundColor White
    
    $manualStart = Read-Host "`nWould you like to start the KeepAwake script manually? (Y/N)"
    if ($manualStart -eq 'Y' -or $manualStart -eq 'y') {
        Start-KeepAwakeManually
    }
} else {
    # Sort log files by relevance only if array contains items
    if ($logFilesArray.Count -gt 0) {
        # Create a new ArrayList for the sorted results
        $sortedArray = [System.Collections.ArrayList]::new()
        
        # Sort by custom criteria - convert to array temporarily for sorting operation
        $tempSorted = @($logFilesArray) | Sort-Object -Property @{Expression = {$_.IsCurrentUser}; Descending = $true}, @{Expression = {$_.LastWriteTime}; Descending = $true}
        
        # Copy back to ArrayList
        foreach ($item in $tempSorted) {
            [void]$sortedArray.Add($item)
        }
        
        # Replace with sorted array
        $logFilesArray = $sortedArray
    }
    
    Write-Host "`nFound $($logFilesArray.Count) log file(s):" -ForegroundColor Green
    
    # Display the log files with options
    for ($i = 0; $i -lt $logFilesArray.Count; $i++) {
        $logFile = $logFilesArray[$i]
        $highlightColor = if ($logFile.IsCurrentUser) { "Green" } else { "White" }
        Write-Host "[$($i+1)] $($logFile.Path)" -ForegroundColor $highlightColor
        Write-Host "    Type: $($logFile.Type)" -ForegroundColor Gray
        Write-Host "    Last Modified: $($logFile.LastWriteTime)" -ForegroundColor Gray
    }
    
    # Add option to restart KeepAwake
    Write-Host "`n[R] Restart KeepAwake Task" -ForegroundColor Magenta
    Write-Host "[M] Start KeepAwake Manually" -ForegroundColor Magenta
    
    # Prompt user to select a log file
    $selection = ""
    do {
        try {
            $input = Read-Host "`nEnter the number of the log file to view (or 'R' to restart, 'M' for manual start, 'Q' to quit)"
            if ($input -eq 'Q' -or $input -eq 'q') {
                exit
            } elseif ($input -eq 'R' -or $input -eq 'r') {
                $selection = "RESTART"
                break
            } elseif ($input -eq 'M' -or $input -eq 'm') {
                $selection = "MANUAL"
                break
            }
            
            $selectionNum = [int]$input
            if ($selectionNum -lt 1 -or $selectionNum -gt $logFilesArray.Count) {
                Write-Host "Invalid selection. Please enter a number between 1 and $($logFilesArray.Count), or 'R', 'M', or 'Q'." -ForegroundColor Red
                $selection = ""
            } else {
                $selection = $selectionNum
            }
        } catch {
            Write-Host "Invalid input. Please enter a number, 'R', 'M', or 'Q'." -ForegroundColor Red
            $selection = ""
        }
    } while ($selection -eq "")
    
    # Handle the selection
    if ($selection -eq "RESTART") {
        try {
            $taskName = "KeepAwakeTask"
            Write-Host "Stopping task if running..." -ForegroundColor Cyan
            Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue | Out-Null
            
            Write-Host "Starting task..." -ForegroundColor Cyan
            Start-ScheduledTask -TaskName $taskName
            
            Write-Host "Task restarted successfully. Run this script again to check the logs after a few moments." -ForegroundColor Green
        } catch {
            Write-Host "Failed to restart task: $_" -ForegroundColor Red
        }
    } elseif ($selection -eq "MANUAL") {
        Start-KeepAwakeManually
    } else {
        # Display the selected log file
        $selectedLog = $logFilesArray[$selection-1].Path
        Write-Host "`nDisplaying log file: $selectedLog" -ForegroundColor Cyan
        Write-Host "----------------------------------------" -ForegroundColor Cyan
        
        try {
            if ((Get-Item $selectedLog).Length -gt 10KB) {
                Write-Host "Log file is large. Showing the last 20 entries:" -ForegroundColor Yellow
                Get-Content -Path $selectedLog -Tail 20 -ErrorAction Stop
                
                $showMore = Read-Host "`nShow the entire log file? (Y/N)"
                if ($showMore -eq 'Y' -or $showMore -eq 'y') {
                    Get-Content -Path $selectedLog -ErrorAction Stop
                }
            } else {
                Get-Content -Path $selectedLog -ErrorAction Stop
            }
            
            # Offer to open the log file in Notepad
            $openNotepad = Read-Host "`nOpen this log file in Notepad? (Y/N)"
            if ($openNotepad -eq 'Y' -or $openNotepad -eq 'y') {
                Start-Process notepad.exe -ArgumentList $selectedLog
            }
        }
        catch {
            Write-Host "Error reading log file: $_" -ForegroundColor Red
        }
    }
}

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") 