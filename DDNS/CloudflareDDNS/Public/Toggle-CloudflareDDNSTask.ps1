function Toggle-CloudflareDDNSTask {
    [CmdletBinding()]
    param()
    
    $taskName = "CloudflareDDNS"
    
    try {
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
        
        if ($task.State -eq "Disabled") {
            # Task is disabled, enable it
            Enable-ScheduledTask -TaskName $taskName | Out-Null
            Write-CloudflareDDNSLog -Message "Scheduled task '$taskName' has been enabled" -Status "INFO" -Color "Green"
            Write-Host "Scheduled task '$taskName' has been enabled." -ForegroundColor Green
        }
        else {
            # Task is enabled, disable it
            Disable-ScheduledTask -TaskName $taskName | Out-Null
            Write-CloudflareDDNSLog -Message "Scheduled task '$taskName' has been disabled" -Status "INFO" -Color "Yellow"
            Write-Host "Scheduled task '$taskName' has been disabled." -ForegroundColor Yellow
        }
        
        return $true
    }
    catch [Microsoft.PowerShell.Cmdletization.Cim.CimJobException] {
        Write-CloudflareDDNSLog -Message "Failed to toggle task '$taskName' - task not found" -Status "ERROR" -Color "Red"
        Write-Host "Scheduled task '$taskName' was not found." -ForegroundColor Red
        return $false
    }
    catch {
        Write-CloudflareDDNSLog -Message "Error toggling scheduled task: $_" -Status "ERROR" -Color "Red"
        Write-Host "Error toggling scheduled task: $_" -ForegroundColor Red
        return $false
    }
} 