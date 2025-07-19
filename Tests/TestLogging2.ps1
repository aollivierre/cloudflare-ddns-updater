#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Test script for .NET StreamWriter logging in SYSTEM context
.DESCRIPTION
    Uses the .NET StreamWriter approach with FileShare mode to test logging in SYSTEM context
#>

# Define log path
$logDir = "C:\ProgramData\LogTest2"
$logFile = "$logDir\system_test_2.log"

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

# Initialize the log file 
try {
    # Create the file if it doesn't exist
    if (!(Test-Path $logFile)) {
        [System.IO.File]::WriteAllText($logFile, "")
    }
    
    # Set permissions on the file
    $acl = Get-Acl -Path $logFile
    $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "Allow")
    $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "Allow")
    $acl.AddAccessRule($systemRule)
    $acl.AddAccessRule($everyoneRule)
    Set-Acl -Path $logFile -AclObject $acl
    
    # Initial content using StreamWriter
    $writer = [System.IO.StreamWriter]::new($logFile, $true)
    $writer.WriteLine("Log file created at $(Get-Date)")
    
    # Write diagnostic info
    $diagInfo = @"
=== System Log Test 2 (.NET StreamWriter) ===
Date: $(Get-Date)
User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
OS: $([System.Environment]::OSVersion.VersionString)
PowerShell: $($PSVersionTable.PSVersion)
TEMP: $env:TEMP
ProgramData: $env:ProgramData
"@
    
    $writer.WriteLine($diagInfo)
    $writer.Flush()
    $writer.Close()
    $writer.Dispose()
}
catch {
    Write-Host "Error initializing log file: $_" -ForegroundColor Red
}

# Create a script file that will be run by the scheduled task
$scriptContent = @'
try {
    # Set up the stream writer with shared access
    $logFile = "{0}"
    $writer = [System.IO.StreamWriter]::new($logFile, $true, [System.Text.Encoding]::UTF8, [System.IO.FileShare]::ReadWrite)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $writer.WriteLine("[$timestamp] Task executed with StreamWriter")
    $writer.Flush()
    $writer.Close()
    $writer.Dispose()
    
    # Also try direct file API as a test
    [System.IO.File]::AppendAllText($logFile, "`r`n[$timestamp] Task executed with File.AppendAllText")
}
catch {
    # If logging fails, write to a temp file
    $errorMsg = "Error in task: $_"
    [System.IO.File]::WriteAllText("$env:TEMP\logging_test2_error.log", $errorMsg)
}
'@ -f $logFile

$taskScriptPath = "$logDir\LogTask2.ps1"
Set-Content -Path $taskScriptPath -Value $scriptContent -Force

# Create a scheduled task to run the log test
$taskName = "LoggingTest2"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$taskScriptPath`""
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the task
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal | Out-Null

Write-Host "Setup complete!" -ForegroundColor Green
Write-Host "Log file created at: $logFile" -ForegroundColor Cyan
Write-Host "Scheduled task '$taskName' will run in 1 minute" -ForegroundColor Cyan
Write-Host "You can also manually run the task from Task Scheduler" -ForegroundColor Cyan
Write-Host "After the task runs, check the log file to see if the entry was added" -ForegroundColor Yellow 