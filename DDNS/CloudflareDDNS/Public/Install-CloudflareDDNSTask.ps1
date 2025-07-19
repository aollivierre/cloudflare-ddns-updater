function Install-CloudflareDDNSTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$UseVBScript = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$CustomInterval = ""
    )
    
    Write-CloudflareDDNSLog -Message "Installing scheduled task" -Status "INFO" -Color "White"
    
    # Find the module path
    $modulePath = Split-Path -Parent $script:ModuleRoot
    $taskCommand = "powershell.exe"
    
    $taskName = "CloudflareDDNS"
    
    # Create arguments for silent execution
    $programDataDir = "$env:ProgramData\CloudflareDDNS"
    $programDataLogDir = "$programDataDir\logs"
    $scriptsDir = "$programDataDir\scripts"
    
    # Create necessary directories
    foreach ($dir in @($programDataDir, $programDataLogDir, $scriptsDir)) {
        if (!(Test-Path -Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
            
            # Ensure Everyone has write permissions to the directory
            $acl = Get-Acl -Path $dir
            $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Modify", "ContainerInherit,ObjectInherit", "None", "Allow")
            $acl.SetAccessRule($accessRule)
            Set-Acl -Path $dir -AclObject $acl
        }
    }
    
    # Create a task script file
    $taskScriptPath = "$scriptsDir\Update-CloudflareDDNS-Task.ps1"
    $taskScript = @"
#Requires -Version 5.1
<#
.SYNOPSIS
    Scheduled task script to update Cloudflare DNS records.
.DESCRIPTION
    This script is automatically created by the CloudflareDDNS module.
    It updates Cloudflare DNS records with the current public IP address.
.NOTES
    Created by: Install-CloudflareDDNSTask function
    Creation Date: $(Get-Date -Format "yyyy-MM-dd")
#>

# Define log paths
`$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
`$logPath = "$programDataLogDir\cloudflare_ddns_task_`$timestamp.log"
`$errorLogPath = "$programDataLogDir\cloudflare_ddns_error.log"
`$outputLogPath = "$programDataLogDir\cloudflare_ddns_output.log"
`$errorsLogPath = "$programDataLogDir\cloudflare_ddns_errors.log"

# Redirect all output
Start-Transcript -Path `$outputLogPath -Append

try {
    # Import module and run the update function
    Import-Module CloudflareDDNS -ErrorAction Stop
    Update-CloudflareDNSRecord -ForceDirect -LogPath `$logPath
}
catch {
    # Log errors
    `$errorMessage = `$_.Exception.Message
    `$errorLine = `$_.InvocationInfo.ScriptLineNumber
    `$errorScript = `$_.InvocationInfo.ScriptName
    
    "ERROR at `$(`$errorScript):line `$(`$errorLine)" | Out-File -FilePath `$errorLogPath -Append
    `$error[0] | Out-File -FilePath `$errorLogPath -Append
}
finally {
    Stop-Transcript
}
"@

    # Save the task script
    Set-Content -Path $taskScriptPath -Value $taskScript -Force
    
    # Update arguments to call the script file instead of using inline command
    $actionArgs = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$taskScriptPath`""
    
    try {
        # Delete existing task if it exists
        $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($taskExists) {
            Write-Host "Removing existing task..." -ForegroundColor Yellow
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
        }
        
        # Get the current time for StartBoundary
        $startBoundary = (Get-Date).AddMinutes(1).ToString("yyyy-MM-ddTHH:mm:ss.000") + (Get-Date).ToString("zzz")
        
        # Create comprehensive XML task definition with multiple triggers
        $escapedActionArgs = [System.Security.SecurityElement]::Escape($actionArgs)
        $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <URI>\$taskName</URI>
    <Description>Updates Cloudflare DNS records when public IP changes</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
    <TimeTrigger>
      <Repetition>
        <Interval>PT4H</Interval>
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
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
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
      <Command>$taskCommand</Command>
      <Arguments>$escapedActionArgs</Arguments>
    </Exec>
  </Actions>
</Task>
"@
        
        # Register the task using the XML definition
        Register-ScheduledTask -TaskName $taskName -Xml $taskXml -Force | Out-Null
        
        Write-CloudflareDDNSLog -Message "Successfully installed scheduled task '$taskName'" -Status "SUCCESS" -Color "Green"
        Write-Host "Scheduled task '$taskName' has been created successfully." -ForegroundColor Green
        Write-Host ""
        Write-Host "The task will run with the following triggers:" -ForegroundColor White
        Write-Host "- At user logon" -ForegroundColor Yellow
        Write-Host "- Every minute (for quick network change detection)" -ForegroundColor Yellow
        Write-Host "- Every 4 hours (regular check)" -ForegroundColor Yellow
        Write-Host "- At startup (after a 1-minute delay)" -ForegroundColor Yellow
        Write-Host "- When network profile changes (EventID 10000/10001)" -ForegroundColor Yellow
        Write-Host "- When network adapter disconnects (EventID 4202)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "This ensures your DNS records are updated promptly whenever your network changes." -ForegroundColor Green
        
        # Trigger the task to run immediately
        $runNow = Read-Host "Would you like to run the task now? (Y/N)"
        if ($runNow.ToUpper() -eq "Y") {
            Write-Host "Triggering task to run now..." -ForegroundColor Cyan
            Start-ScheduledTask -TaskName $taskName
        }
    }
    catch {
        Write-CloudflareDDNSLog -Message "Failed to create scheduled task: $_" -Status "ERROR" -Color "Red"
        Write-Host "Error creating scheduled task: $_" -ForegroundColor Red
    }
} 