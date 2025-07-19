#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Test script for Windows Event Log logging in SYSTEM context
.DESCRIPTION
    Uses the Windows Event Log for guaranteed logging in SYSTEM context
#>

# Define log path (for file logging too)
$logDir = "C:\ProgramData\LogTest3"
$logFile = "$logDir\system_test_3.log"

# Create log directory with permissions
if (!(Test-Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
    
    # Set explicit permissions
    $acl = Get-Acl -Path $logDir
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.AddAccessRule($systemRule)
    $acl.AddAccessRule($everyoneRule)
    Set-Acl -Path $logDir -AclObject $acl
}

# Create a new event log source if it doesn't exist
$logName = "Application"
$sourceName = "SystemLoggingTest"

if (![System.Diagnostics.EventLog]::SourceExists($sourceName)) {
    try {
        [System.Diagnostics.EventLog]::CreateEventSource($sourceName, $logName)
        Write-Host "Created new event source: $sourceName" -ForegroundColor Green
    }
    catch {
        Write-Host "Error creating event source: $_" -ForegroundColor Red
    }
}

# Write a test event to the event log
try {
    $diagInfo = @"
=== System Log Test 3 (Event Log) ===
Date: $(Get-Date)
User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
OS: $([System.Environment]::OSVersion.VersionString)
PowerShell: $($PSVersionTable.PSVersion)
TEMP: $env:TEMP
ProgramData: $env:ProgramData
"@
    
    [System.Diagnostics.EventLog]::WriteEntry($sourceName, "Test event written from setup script`n$diagInfo", [System.Diagnostics.EventLogEntryType]::Information, 1000)
    Write-Host "Test event written to event log" -ForegroundColor Green
    
    # Also try file logging
    Set-Content -Path $logFile -Value "Log file created at $(Get-Date)`r`n$diagInfo" -Force
}
catch {
    Write-Host "Error writing to event log: $_" -ForegroundColor Red
}

# Create a task script
$scriptContent = @'
try {
    # Write to the Event Log
    [System.Diagnostics.EventLog]::WriteEntry("{0}", "Task executed at $(Get-Date) by $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)", [System.Diagnostics.EventLogEntryType]::Information, 1001)
    
    # Also try file logging
    $logFile = "{1}"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] Task executed by $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
    
    # Try multiple logging methods
    try {{ Add-Content -Path $logFile -Value "Method 1: $logEntry" -Force }} catch {{ }}
    try {{ [System.IO.File]::AppendAllText($logFile, "`r`nMethod 2: $logEntry") }} catch {{ }}
    
    # Write environment details to help diagnose issues
    $envInfo = @"
SYSTEM Context Environment:
WindowsIdentity: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
TEMP: $env:TEMP
ProgramData: $env:ProgramData
Current Directory: $(Get-Location)
"@
    [System.Diagnostics.EventLog]::WriteEntry("{0}", $envInfo, [System.Diagnostics.EventLogEntryType]::Information, 1002)
}
catch {{
    # Last resort logging to temp directory
    $errorFile = "$env:TEMP\eventlog_error.txt"
    $errorMsg = "Error in task: $_"
    [System.IO.File]::WriteAllText($errorFile, $errorMsg)
}}
'@ -f $sourceName, $logFile

$taskScriptPath = "$logDir\LogTask3.ps1"
Set-Content -Path $taskScriptPath -Value $scriptContent -Force

# Create a scheduled task to run the log test
$taskName = "LoggingTest3"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$taskScriptPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the task
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal | Out-Null

Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "Check Event Viewer > Windows Logs > Application for source '$sourceName'" -ForegroundColor Cyan
Write-Host "Also check log file at: $logFile" -ForegroundColor Cyan
Write-Host "Scheduled task '$taskName' will run in 1 minute" -ForegroundColor Cyan
Write-Host "You can also manually run the task from Task Scheduler" -ForegroundColor Cyan
Write-Host "After the task runs, check both the Event Log and log file" -ForegroundColor Yellow 