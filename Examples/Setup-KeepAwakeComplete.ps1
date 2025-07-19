# Setup-KeepAwakeComplete.ps1
# This script creates a scheduled task to run KeepAwake and offers the option to run it visibly or invisibly

#Requires -RunAsAdministrator

# Define log file path that works for both user and SYSTEM contexts
$script:LogFile = "$env:ProgramData\KeepAwake\KeepAwake-Setup.log"

function Write-KeepAwakeLog {
    param(
        [string]$Message,
        [string]$Status = "INFO",
        [string]$Color = "White"
    )
    
    # Ensure log directory exists
    $logDir = Split-Path -Parent $script:LogFile
    if (-not (Test-Path $logDir)) {
        try {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        catch {
            # If we can't create the directory, fallback to temp
            $script:LogFile = "$env:TEMP\KeepAwake-Setup.log"
            $logDir = Split-Path -Parent $script:LogFile
            
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null
            }
        }
    }
    
    # Check log file size and implement rotation if needed
    if ((Test-Path $script:LogFile) -and ((Get-Item $script:LogFile).Length -gt 100KB)) {
        # Create a timestamp for the backup log
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupLog = "$script:LogFile.$timestamp.bak"
        
        # Move current log to backup
        try {
            Copy-Item -Path $script:LogFile -Destination $backupLog -Force -ErrorAction SilentlyContinue
            "Log file rotation occurred at $(Get-Date)" | Set-Content -Path $script:LogFile -ErrorAction SilentlyContinue
        }
        catch {
            # Just continue if we can't rotate logs
        }
    }
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Status] $Message"
    
    # Add to log file
    try {
        Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction Stop
    }
    catch {
        # If we can't write to the log, try alternate location
        $tempLogFile = "$env:TEMP\KeepAwake-Setup.emergency.log"
        $errorMsg = "[$timestamp] [ERROR] Failed to write to primary log. See error details on next line."
        $errorDetails = "[$timestamp] [ERROR] $($_.Exception.Message)"
        $logLocationMsg = "[$timestamp] [INFO] Using alternate log location $tempLogFile"
        Add-Content -Path $tempLogFile -Value $errorMsg -ErrorAction SilentlyContinue
        Add-Content -Path $tempLogFile -Value $errorDetails -ErrorAction SilentlyContinue
        Add-Content -Path $tempLogFile -Value $logLocationMsg -ErrorAction SilentlyContinue
        Add-Content -Path $tempLogFile -Value $logMessage -ErrorAction SilentlyContinue
    }
    
    # Output to console with appropriate color
    Write-Host $Message -ForegroundColor $Color
}

function Initialize-LogFile {
    # Make sure log directory exists
    $logDir = Split-Path -Parent $script:LogFile
    if (-not (Test-Path $logDir)) {
        try {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            Write-Host "Created log directory: $logDir" -ForegroundColor Green
        }
        catch {
            Write-Host "Could not create log directory $logDir. Using $env:TEMP instead." -ForegroundColor Yellow
            $script:LogFile = "$env:TEMP\KeepAwake-Setup.log"
        }
    }
    
    # If the log file doesn't exist or is very old (>7 days), create a new one
    if (-not (Test-Path $script:LogFile) -or 
        ((Get-Item $script:LogFile).LastWriteTime -lt (Get-Date).AddDays(-7))) {
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        try {
            "[${timestamp}] [SYSTEM] Log file initialized." | Set-Content -Path $script:LogFile
        }
        catch {
            Write-Host "Could not initialize log file at $script:LogFile. Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

function Show-LogFile {
    $primaryLogFile = $script:LogFile
    $emergencyLogFile = "$env:TEMP\KeepAwake-Setup.emergency.log"
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
        Write-Host "This could be the first time running the script." -ForegroundColor Yellow
        
        # Try to find any KeepAwake setup log files in common locations
        $possibleLogFiles = @(
            "$env:ProgramData\KeepAwake\*.log",
            "$env:TEMP\KeepAwake-*.log",
            "C:\Windows\Temp\KeepAwake-*.log"
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

function Clear-LogFile {
    Write-Host "Clearing log file..." -ForegroundColor Yellow
    
    # Check if log file exists
    if (Test-Path $script:LogFile) {
        try {
            # Create timestamp
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            # Backup old log before clearing
            $backupFile = "$script:LogFile.old"
            Copy-Item -Path $script:LogFile -Destination $backupFile -Force
            
            # Create fresh log with header
            "[${timestamp}] [SYSTEM] Log file cleared. Previous log saved to: $backupFile" | Set-Content -Path $script:LogFile
            Write-Host "Log file has been cleared. Previous logs backed up to: $backupFile" -ForegroundColor Green
        }
        catch {
            Write-Host "Error clearing log file: $_" -ForegroundColor Red
        }
    }
    else {
        # If no log file exists, create a new one
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[${timestamp}] [SYSTEM] New log file initialized." | Set-Content -Path $script:LogFile
        Write-Host "No log file found. Created a new log file." -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
    Read-Host
}

function Test-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Show-Menu {
    Clear-Host
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "    KEEPAWAKE COMPLETE SETUP             " -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " This tool helps set up the KeepAwake task" -ForegroundColor White
    Write-Host " to keep your system from going to sleep." -ForegroundColor White
    Write-Host ""
    Write-Host " Select an option:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host " 1: Setup KeepAwake Task" -ForegroundColor Green
    Write-Host " 2: Check KeepAwake Status and Logs" -ForegroundColor Green
    Write-Host " 3: View Setup Log File" -ForegroundColor Green
    Write-Host " 4: Clear Setup Log File" -ForegroundColor Green
    Write-Host " Q: Quit" -ForegroundColor Green
    Write-Host ""
    
    $selection = Read-Host "Enter your choice (1-4 or Q)"
    
    switch ($selection.ToUpper()) {
        "1" { 
            Setup-KeepAwakeWithOptions
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            return $true
        }
        "2" { 
            Run-KeepAwakeLogChecker
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
        "Q" { return $false }
        default { 
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
            return $true
        }
    }
}

function CreateVBScript {
    param (
        [string]$scriptPath
    )
    
    $vbsContent = @"
' KeepAwakeInvisible.vbs
' This script launches PowerShell completely hidden without showing any window
' Created to solve the issue of visible windows when using -WindowStyle Hidden

Option Explicit

' Define the path to PowerShell and the script
Dim PowerShellPath, ScriptPath, Arguments
PowerShellPath = "powershell.exe"
ScriptPath = "$scriptPath"
Arguments = "-NoProfile -ExecutionPolicy Bypass -File """ & ScriptPath & """"

' Create a shell object
Dim objShell
Set objShell = CreateObject("WScript.Shell")

' Run PowerShell with 0 window style (hidden)
' 0 = Hidden window
' True = don't wait for program to finish
objShell.Run PowerShellPath & " " & Arguments, 0, False

' Clean up
Set objShell = Nothing
"@

    $vbsPath = Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "KeepAwakeInvisible.vbs"
    $vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force
    
    Write-KeepAwakeLog "Created VBScript wrapper at $vbsPath" -Status "INFO" -Color "Green"
    return $vbsPath
}

function SetupKeepAwakeTask {
    param (
        [bool]$invisible = $false
    )
    
    Write-KeepAwakeLog "Setting up KeepAwake scheduled task..." -Status "INFO" -Color "Cyan"
    
    # Get current script directory
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = (Get-Location).Path
    }
    
    # Check if KeepAwakeSystem.ps1 exists
    $keepAwakeSystemPath = Join-Path -Path $scriptDir -ChildPath "KeepAwakeSystem.ps1"
    if (-not (Test-Path -Path $keepAwakeSystemPath)) {
        # Look for KeepAwake.ps1 instead
        $keepAwakeSystemPath = Join-Path -Path $scriptDir -ChildPath "KeepAwake.ps1"
        if (-not (Test-Path -Path $keepAwakeSystemPath)) {
            Write-KeepAwakeLog "ERROR: Could not find KeepAwakeSystem.ps1 or KeepAwake.ps1 in the current directory." -Status "ERROR" -Color "Red"
            return $false
        }
        
        Write-KeepAwakeLog "Using KeepAwake.ps1 instead of KeepAwakeSystem.ps1" -Status "WARNING" -Color "Yellow"
    }
    
    # Convert to absolute path
    $keepAwakeSystemPath = (Get-Item $keepAwakeSystemPath).FullName
    Write-KeepAwakeLog "Found script at: $keepAwakeSystemPath" -Status "INFO" -Color "Green"
    
    # Create VBS script if invisible mode is selected
    if ($invisible) {
        Write-KeepAwakeLog "Creating VBScript wrapper for invisible operation..." -Status "INFO" -Color "Cyan"
        $vbsPath = CreateVBScript -scriptPath $keepAwakeSystemPath
        $actionPath = "wscript.exe"
        $actionArgs = "`"$vbsPath`""
        Write-KeepAwakeLog "VBScript created at: $vbsPath" -Status "INFO" -Color "Green"
    } else {
        $actionPath = "powershell.exe"
        $actionArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$keepAwakeSystemPath`""
    }
    
    # Define task details
    $taskName = "KeepAwakeTask"
    $description = "Prevents system from sleeping by using Windows API calls"
    
    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($existingTask) {
        Write-KeepAwakeLog "Task '$taskName' already exists. Removing it first..." -Status "WARNING" -Color "Yellow"
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
        Write-KeepAwakeLog "Existing task removed successfully." -Status "INFO" -Color "Green"
    }
    
    # Create task action
    $taskAction = New-ScheduledTaskAction -Execute $actionPath -Argument $actionArgs
    
    # Create task trigger for logon
    $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
    
    # Set task settings (don't stop on battery, allow on demand start, etc)
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
    
    # Set task to run with highest privileges for Users group
    $taskPrincipal = New-ScheduledTaskPrincipal -GroupId "Users" -RunLevel Highest
    
    # Create the task
    try {
        Write-KeepAwakeLog "Registering scheduled task..." -Status "INFO" -Color "Cyan"
        Register-ScheduledTask -TaskName $taskName -Description $description -Action $taskAction -Trigger $taskTrigger -Settings $taskSettings -Principal $taskPrincipal -Force -ErrorAction Stop
        
        # Verify task was created
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        if ($task) {
            $invisibleText = if ($invisible) { "invisibly (no console window)" } else { "visibly (with console window)" }
            Write-KeepAwakeLog "Success! KeepAwake scheduled task created successfully." -Status "INFO" -Color "Green"
            Write-KeepAwakeLog "Task will run $invisibleText at each user logon." -Status "INFO" -Color "Green"
            Write-KeepAwakeLog "You can verify the task in Task Scheduler or run Check-KeepAwakeLog.ps1 to check status." -Status "INFO" -Color "Cyan"
            return $true
        } else {
            Write-KeepAwakeLog "Task creation failed for unknown reason." -Status "ERROR" -Color "Red"
            return $false
        }
    }
    catch {
        Write-KeepAwakeLog "Error creating scheduled task: $_" -Status "ERROR" -Color "Red"
        return $false
    }
}

function Setup-KeepAwakeWithOptions {
    # Prompt user for visibility preference
    Write-Host "`nDo you want KeepAwake to run invisibly (no console window) or visibly (with console window)?" -ForegroundColor Yellow
    Write-Host "1. Invisibly - recommended for regular use (no visible console window)" -ForegroundColor White
    Write-Host "2. Visibly - useful for troubleshooting (console window will be visible)" -ForegroundColor White

    $choice = ""
    do {
        $input = Read-Host "`nEnter your choice (1 or 2)"
        if ($input -eq "1" -or $input -eq "2") {
            $choice = $input
        } else {
            Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Red
        }
    } while ($choice -eq "")

    $invisible = ($choice -eq "1")

    # Setup the task
    $result = SetupKeepAwakeTask -invisible $invisible

    if ($result) {
        Write-KeepAwakeLog "Setup complete! KeepAwake will now run automatically when any user logs in." -Status "INFO" -Color "Green"
        
        # Offer to start the task now
        $startNow = Read-Host "`nWould you like to start the KeepAwake task now? (Y/N)"
        if ($startNow -eq 'Y' -or $startNow -eq 'y') {
            try {
                Start-ScheduledTask -TaskName "KeepAwakeTask"
                Write-KeepAwakeLog "KeepAwake task started successfully!" -Status "INFO" -Color "Green"
                Write-KeepAwakeLog "Run Check-KeepAwakeLog.ps1 to verify it's working properly." -Status "INFO" -Color "Cyan"
            } catch {
                Write-KeepAwakeLog "Failed to start task: $_" -Status "ERROR" -Color "Red"
            }
        }
    } else {
        Write-KeepAwakeLog "Setup failed. Please check the error messages and try again." -Status "ERROR" -Color "Red"
    }
}

function Run-KeepAwakeLogChecker {
    Write-KeepAwakeLog "Running Check-KeepAwakeLog.ps1 to view KeepAwake status and logs..." -Status "INFO" -Color "Cyan"
    
    # Get current script directory
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = (Get-Location).Path
    }
    
    # Check if Check-KeepAwakeLog.ps1 exists
    $checkLogScriptPath = Join-Path -Path $scriptDir -ChildPath "Check-KeepAwakeLog.ps1"
    if (-not (Test-Path -Path $checkLogScriptPath)) {
        Write-KeepAwakeLog "ERROR: Could not find Check-KeepAwakeLog.ps1 in the current directory." -Status "ERROR" -Color "Red"
        Write-Host "`nThe Check-KeepAwakeLog.ps1 script was not found at: $checkLogScriptPath" -ForegroundColor Red
        Write-Host "This script is needed to check KeepAwake status and view log files." -ForegroundColor Red
        
        $altPath = Read-Host "`nEnter the full path to Check-KeepAwakeLog.ps1 or press Enter to cancel"
        if ($altPath -and (Test-Path -Path $altPath)) {
            $checkLogScriptPath = $altPath
        } else {
            Write-Host "Operation cancelled." -ForegroundColor Yellow
            Write-Host "`nPress Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            return
        }
    }
    
    try {
        # Run the script in a new PowerShell window
        Write-KeepAwakeLog "Starting Check-KeepAwakeLog.ps1..." -Status "INFO" -Color "Green"
        Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$checkLogScriptPath`"" -Wait
        Write-KeepAwakeLog "Returned from Check-KeepAwakeLog.ps1" -Status "INFO" -Color "Green"
    } catch {
        Write-KeepAwakeLog "Error running Check-KeepAwakeLog.ps1: $_" -Status "ERROR" -Color "Red"
        Write-Host "`nEncountered an error: $_" -ForegroundColor Red
        Write-Host "`nPress Enter to return to the menu..." -ForegroundColor Cyan
        Read-Host
    }
}

# Main script execution
Initialize-LogFile
Write-KeepAwakeLog "KeepAwake Setup started" -Status "INFO" -Color "Cyan"

# Check if running as administrator
if (-not (Test-Administrator)) {
    Write-KeepAwakeLog "This script requires administrator privileges." -Status "ERROR" -Color "Red"
    Write-KeepAwakeLog "Please run PowerShell as Administrator and try again." -Status "ERROR" -Color "Red"
    exit
}

# Show interactive menu
$continueRunning = $true
while ($continueRunning) {
    $continueRunning = Show-Menu
}

Write-KeepAwakeLog "KeepAwake Setup completed" -Status "INFO" -Color "Cyan" 