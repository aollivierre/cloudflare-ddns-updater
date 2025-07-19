function Run-CloudflareDDNSTask {
    [CmdletBinding()]
    param()
    
    $taskName = "CloudflareDDNS"
    
    try {
        # Get the task
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        
        # Run the task
        Start-ScheduledTask -TaskName $taskName
        
        Write-CloudflareDDNSLog -Message "Manually triggered scheduled task '$taskName'" -Status "INFO" -Color "Green"
        
        if ($task.State -ne "Running") {
            Write-CloudflareDDNSLog -Message "Manually triggered scheduled task '$taskName' but status is '$($task.State)'" -Status "INFO" -Color "Yellow"
        }
        
        Write-Host "Scheduled task '$taskName' has been triggered." -ForegroundColor Green
        Write-Host "Check the log file for results: $script:LogFile" -ForegroundColor Cyan
        
        return $true
    }
    catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
        Write-CloudflareDDNSLog -Message "Failed to trigger task '$taskName' - task not found" -Status "ERROR" -Color "Red"
        Write-Host "Scheduled task '$taskName' was not found." -ForegroundColor Red
        return $false
    }
    catch {
        Write-CloudflareDDNSLog -Message "Failed to start scheduled task: $_" -Status "ERROR" -Color "Red"
        Write-Host "Failed to start scheduled task: $_" -ForegroundColor Red
        return $false
    }
} 