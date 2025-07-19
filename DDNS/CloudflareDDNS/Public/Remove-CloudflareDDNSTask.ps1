function Remove-CloudflareDDNSTask {
    [CmdletBinding()]
    param()
    
    $taskName = "CloudflareDDNS"
    
    try {
        # Check if the task exists before attempting removal
        $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        
        if ($task) {
            # Attempt to remove the task
            Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
            
            # Check for VBScript wrapper file in case it was used (legacy support)
            $vbsPath = "$env:ProgramData\CloudflareDDNS\ddns_wrapper.vbs"
            if (Test-Path $vbsPath) {
                Remove-Item -Path $vbsPath -Force
                Write-CloudflareDDNSLog -Message "Removed VBS wrapper file: $vbsPath" -Status "INFO" -Color "Yellow"
            }
            
            Write-CloudflareDDNSLog -Message "Scheduled task '$taskName' has been removed" -Status "INFO" -Color "Yellow"
            Write-Host "Scheduled task '$taskName' has been removed." -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "Scheduled task '$taskName' was not found." -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-CloudflareDDNSLog -Message "Failed to remove scheduled task: $_" -Status "ERROR" -Color "Red"
        Write-Host "Failed to remove scheduled task: $_" -ForegroundColor Red
        return $false
    }
} 