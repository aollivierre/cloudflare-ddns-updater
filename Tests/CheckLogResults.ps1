#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Checks the results of the logging tests
.DESCRIPTION
    Examines all three logging methods to determine which ones worked in SYSTEM context
#>

# Define paths to check
$logPaths = @(
    @{ Method = "Method 1 (Add-Content)"; Path = "C:\ProgramData\LogTest1\system_test_1.log" },
    @{ Method = "Method 2 (.NET StreamWriter)"; Path = "C:\ProgramData\LogTest2\system_test_2.log" },
    @{ Method = "Method 3 (Event Log + File)"; Path = "C:\ProgramData\LogTest3\system_test_3.log" }
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     SYSTEM CONTEXT LOGGING TEST RESULTS " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

function Check-EventLog {
    Write-Host "CHECKING EVENT LOG RESULTS:" -ForegroundColor Yellow
    Write-Host "-------------------------" -ForegroundColor Yellow
    
    try {
        $events = Get-EventLog -LogName Application -Source "SystemLoggingTest" -Newest 5 -ErrorAction Stop
        if ($events) {
            Write-Host "SUCCESS: Event Log entries were created!" -ForegroundColor Green
            foreach ($event in $events) {
                $type = switch ($event.EntryType) {
                    "Error" { "Error" }
                    "Warning" { "Warning" }
                    "Information" { "Info" }
                    default { $event.EntryType }
                }
                Write-Host "  [ID: $($event.EventID)] [$type] $($event.TimeGenerated)" -ForegroundColor White
                
                # Show a summary of the message (first 100 chars)
                $msgSummary = if ($event.Message.Length -gt 100) { 
                    $event.Message.Substring(0, 100) + "..." 
                } else { 
                    $event.Message 
                }
                Write-Host "    $msgSummary" -ForegroundColor Gray
            }
        } else {
            Write-Host "No event log entries found for source 'SystemLoggingTest'" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "ERROR checking event log: $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

function Check-LogFiles {
    Write-Host "CHECKING LOG FILE RESULTS:" -ForegroundColor Yellow
    Write-Host "-------------------------" -ForegroundColor Yellow
    
    $successCount = 0
    
    foreach ($log in $logPaths) {
        Write-Host "Checking $($log.Method)" -ForegroundColor Cyan
        if (Test-Path $log.Path) {
            $fileInfo = Get-Item $log.Path
            $lastWriteTime = $fileInfo.LastWriteTime
            $content = Get-Content -Path $log.Path -ErrorAction SilentlyContinue -Tail 10
            
            if ($content -match "Task executed") {
                $successCount++
                Write-Host "  SUCCESS: Logging worked! Entries were added by the scheduled task." -ForegroundColor Green
                Write-Host "  Last write time: $lastWriteTime" -ForegroundColor White
                Write-Host "  Content (last few lines):" -ForegroundColor White
                $content | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
            } else {
                Write-Host "  PARTIAL: Log file exists but no task entries found." -ForegroundColor Yellow
                Write-Host "  Last write time: $lastWriteTime" -ForegroundColor White
                Write-Host "  Content may only show initialization entries." -ForegroundColor Yellow
            }
        } else {
            Write-Host "  FAILED: Log file does not exist" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    return $successCount
}

function Check-ErrorLogs {
    Write-Host "CHECKING FOR ERROR LOGS:" -ForegroundColor Yellow
    Write-Host "----------------------" -ForegroundColor Yellow
    
    # Check all possible error log locations
    $errorPaths = @(
        "$env:TEMP\system_log_test_1_error.log",
        "$env:TEMP\system_log_test_2_error.log",
        "$env:TEMP\logging_test2_error.log",
        "$env:TEMP\eventlog_error.txt"
    )
    
    $foundErrors = $false
    
    foreach ($path in $errorPaths) {
        if (Test-Path $path) {
            $foundErrors = $true
            Write-Host "Found error log: $path" -ForegroundColor Red
            $content = Get-Content -Path $path
            $content | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
            Write-Host ""
        }
    }
    
    # Also check SYSTEM's temp directory
    $systemTemp = "C:\Windows\System32\config\systemprofile\AppData\Local\Temp"
    $systemErrorLogs = Get-ChildItem -Path $systemTemp -Filter "*error*.log" -ErrorAction SilentlyContinue
    
    if ($systemErrorLogs) {
        $foundErrors = $true
        Write-Host "Found error logs in SYSTEM temp directory:" -ForegroundColor Red
        foreach ($log in $systemErrorLogs) {
            Write-Host "  $($log.FullName)" -ForegroundColor Red
            $content = Get-Content -Path $log.FullName
            $content | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
    }
    
    if (-not $foundErrors) {
        Write-Host "No error logs found." -ForegroundColor Green
    }
    
    Write-Host ""
}

# Check all three logging methods
Check-EventLog
$successCount = Check-LogFiles
Check-ErrorLogs

# Summary and recommendations
Write-Host "SUMMARY:" -ForegroundColor Yellow
Write-Host "-------" -ForegroundColor Yellow
Write-Host "$successCount out of 3 logging methods successfully worked in SYSTEM context." -ForegroundColor Cyan
Write-Host ""

if ($successCount -gt 0) {
    Write-Host "RECOMMENDATION:" -ForegroundColor Green
    Write-Host "--------------" -ForegroundColor Green
    
    if (Test-Path "C:\ProgramData\LogTest3\system_test_3.log" -and (Get-Content "C:\ProgramData\LogTest3\system_test_3.log" -ErrorAction SilentlyContinue) -match "Task executed") {
        Write-Host "The best approach is Method 3 (Event Log + File) because:" -ForegroundColor White
        Write-Host "1. Event logs are always accessible to SYSTEM" -ForegroundColor White
        Write-Host "2. The file-based logging provides convenient text output" -ForegroundColor White
        Write-Host "3. It has multiple fallback mechanisms for reliability" -ForegroundColor White
    }
    elseif (Test-Path "C:\ProgramData\LogTest2\system_test_2.log" -and (Get-Content "C:\ProgramData\LogTest2\system_test_2.log" -ErrorAction SilentlyContinue) -match "Task executed") {
        Write-Host "Method 2 (.NET StreamWriter) worked best because:" -ForegroundColor White
        Write-Host "1. It uses direct .NET I/O classes which bypass some PowerShell limitations" -ForegroundColor White
        Write-Host "2. It properly handles file locking with FileShare modes" -ForegroundColor White
    }
    elseif (Test-Path "C:\ProgramData\LogTest1\system_test_1.log" -and (Get-Content "C:\ProgramData\LogTest1\system_test_1.log" -ErrorAction SilentlyContinue) -match "Task executed") {
        Write-Host "Method 1 (Add-Content) worked, which is the simplest approach" -ForegroundColor White
    }
    
    Write-Host "`nUse this approach in your CloudflareDDNS script." -ForegroundColor Green
} else {
    Write-Host "RECOMMENDATION:" -ForegroundColor Red
    Write-Host "--------------" -ForegroundColor Red
    Write-Host "None of the logging methods worked in SYSTEM context. Consider:" -ForegroundColor White
    Write-Host "1. Running the task as a different user with explicit permissions" -ForegroundColor White
    Write-Host "2. Using the Event Log exclusively for reliable logging" -ForegroundColor White
    Write-Host "3. Setting explicit full control permissions on log directories and files" -ForegroundColor White
} 