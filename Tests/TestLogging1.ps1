#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Test script for basic PowerShell logging in SYSTEM context
.DESCRIPTION
    Uses the simple Add-Content approach to test logging in SYSTEM context
#>

# Define log path
$logDir = "C:\ProgramData\LogTest1"
$logFile = "$logDir\system_test_1.log"

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

# Initial log content
$initialContent = "Log file created at $(Get-Date)`r`n"
Set-Content -Path $logFile -Value $initialContent -Force

# Write diagnostic info
$diagInfo = @"
=== System Log Test 1 (Add-Content) ===
Date: $(Get-Date)
User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
OS: $([System.Environment]::OSVersion.VersionString)
PowerShell: $($PSVersionTable.PSVersion)
TEMP: $env:TEMP
ProgramData: $env:ProgramData
"@

Add-Content -Path $logFile -Value $diagInfo -Force

# Create a scheduled task to run the log test
$taskName = "LoggingTest1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -Command `"Add-Content -Path '$logFile' -Value 'Task executed at $(Get-Date)' -Force`""
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