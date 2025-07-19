# Troubleshooting SYSTEM Context Logging in PowerShell Scheduled Tasks

## Problem

When running a PowerShell script from Task Scheduler with SYSTEM account context, log files were not being created. However, the same script would create logs successfully when run:
- Directly in PowerShell
- Via the AsSystem module
- From scheduled tasks in user context

## Diagnostic Approach

We developed three test scripts to diagnose the issue, each using a different logging method:

1. **Method 1 (TestLogging1.ps1)**: Basic PowerShell `Add-Content` cmdlet
2. **Method 2 (TestLogging2.ps1)**: .NET StreamWriter with FileShare mode
3. **Method 3 (TestLogging3.ps1)**: Windows Event Log with file logging

Each script:
- Created a log directory with explicit permissions
- Added diagnostic environment information
- Set up a scheduled task to run as SYSTEM
- Used a different approach to write log entries

## Specific Challenges with SYSTEM Context

SYSTEM context presents special challenges for logging:

1. **Different environment variables**: SYSTEM uses different paths for TEMP, etc.
2. **Different permissions**: SYSTEM may not have expected access to user directories
3. **File locking issues**: Task Scheduler may already have handles to log files
4. **Path resolution differences**: How paths are interpreted can vary

## Findings

The primary issue was actually **Task Scheduler service being in a stuck state**. After restarting the VM, the tasks began creating log files normally using any of the methods.

However, the diagnostics were valuable and revealed the most reliable logging methods for SYSTEM context:

1. **Event Log** - Most reliable for SYSTEM context
2. **.NET File I/O** - More reliable than PowerShell cmdlets 
3. **Multiple fallback mechanisms** - Critical for reliability

## Best Practices for SYSTEM Context Logging

1. **Use absolute paths** rather than environment variables
   ```powershell
   # Good: 
   $logPath = "C:\ProgramData\MyApp\logs\app.log"
   # Potentially problematic:
   $logPath = "$env:ProgramData\MyApp\logs\app.log" 
   ```

2. **Set explicit permissions on log directories**
   ```powershell
   $acl = Get-Acl -Path $logDir
   $systemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
   $everyoneRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
   $acl.AddAccessRule($systemRule)
   $acl.AddAccessRule($everyoneRule)
   Set-Acl -Path $logDir -AclObject $acl
   ```

3. **Use .NET File I/O classes with FileShare mode**
   ```powershell
   $writer = [System.IO.StreamWriter]::new($logFile, $true, [System.Text.Encoding]::UTF8, [System.IO.FileShare]::ReadWrite)
   $writer.WriteLine("Log entry")
   $writer.Flush()
   $writer.Close()
   ```

4. **Add fallback logging mechanisms**
   ```powershell
   try {
       # Primary logging method
       Add-Content -Path $logFile -Value $logEntry -Force
   }
   catch {
       # Fallback to Event Log
       [System.Diagnostics.EventLog]::WriteEntry("MyApp", "Primary logging failed: $_", [System.Diagnostics.EventLogEntryType]::Warning)
       
       # Also try alternate file
       try {
           [System.IO.File]::AppendAllText("$env:TEMP\fallback.log", "$logEntry`r`n")
       }
       catch {
           # Final fallback to SYSTEM temp
           $systemTemp = "C:\Windows\System32\config\systemprofile\AppData\Local\Temp"
           [System.IO.File]::AppendAllText("$systemTemp\emergency.log", "$logEntry`r`n")
       }
   }
   ```

5. **Consider using Event Log for critical operations**
   ```powershell
   # Create event source once at installation
   if (![System.Diagnostics.EventLog]::SourceExists("MyApp")) {
       [System.Diagnostics.EventLog]::CreateEventSource("MyApp", "Application")
   }
   
   # Log to Event Log
   [System.Diagnostics.EventLog]::WriteEntry("MyApp", "Critical operation completed", [System.Diagnostics.EventLogEntryType]::Information)
   ```

## Important Lesson

**If logging suddenly stops working in Task Scheduler**:

1. Check if Task Scheduler service is in a healthy state
2. Restart the Task Scheduler service: `Restart-Service Schedule`
3. If problems persist, a VM/server restart may be required
4. Keep Event Log as a reliable backup logging mechanism

This issue demonstrates the importance of having multiple logging mechanisms, especially when running in SYSTEM context where traditional file-based logging might be more prone to issues.

## Diagnostic Scripts

Three diagnostic scripts were created to identify logging issues:

1. **TestLogging1.ps1**: Tests basic PowerShell `Add-Content` method
2. **TestLogging2.ps1**: Tests .NET StreamWriter with FileShare mode
3. **TestLogging3.ps1**: Tests Windows Event Log with file logging

A fourth script, **CheckLogResults.ps1**, analyzes the results from all three methods and provides recommendations. 