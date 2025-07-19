function Show-CloudflareDDNSStatus {
    [CmdletBinding()]
    param()
    
    Write-Host "Checking Cloudflare DDNS Status..." -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Get current public IP
    Write-Host "Detecting current public IP address..." -ForegroundColor White
    $publicIP = Get-PublicIP
    
    if (!$publicIP) {
        Write-Host "FAILED to detect public IP address." -ForegroundColor Red
        Write-Host "Please check your internet connection and try again." -ForegroundColor Red
        return
    }
    
    Write-Host "Current public IP: " -NoNewline -ForegroundColor White
    Write-Host "$publicIP" -ForegroundColor Yellow
    Write-Host ""
    
    # Get current DNS record from Cloudflare
    Write-Host "Retrieving current DNS record from Cloudflare..." -ForegroundColor White
    $record = Get-CloudflareRecord
    
    if (!$record) {
        Write-Host "FAILED to retrieve DNS record from Cloudflare." -ForegroundColor Red
        Write-Host "Please check your API settings and network connection." -ForegroundColor Red
        return
    }
    
    $RecordName = "$($script:Config['HostName']).$($script:Config['Domain'])"
    Write-Host "DNS Record: " -NoNewline -ForegroundColor White
    Write-Host "$RecordName" -ForegroundColor Green
    Write-Host "Points to:  " -NoNewline -ForegroundColor White
    Write-Host "$($record.CurrentIP)" -ForegroundColor Yellow
    
    # Compare the values
    Write-Host ""
    Write-Host "Status: " -NoNewline -ForegroundColor White
    
    if ($publicIP -eq $record.CurrentIP) {
        Write-Host "SYNCHRONIZED" -ForegroundColor Green
        Write-Host "Your Cloudflare DNS record is up to date with your current public IP." -ForegroundColor Green
    }
    else {
        Write-Host "OUT OF SYNC" -ForegroundColor Red
        Write-Host "Your Cloudflare DNS record does not match your current public IP." -ForegroundColor Red
        Write-Host "You should update your DNS record using option 1 from the main menu." -ForegroundColor Yellow
    }
    
    # Check last scheduled task execution
    $taskName = "CloudflareDDNS"
    $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    Write-Host ""
    Write-Host "Scheduled Task:" -ForegroundColor White
    
    if ($taskExists) {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction SilentlyContinue
        
        # Task state
        Write-Host "Task State: " -NoNewline -ForegroundColor White
        
        if ($taskExists.State -eq "Ready") {
            Write-Host "Enabled" -ForegroundColor Green
        }
        elseif ($taskExists.State -eq "Disabled") {
            Write-Host "Disabled" -ForegroundColor Red
        }
        else {
            Write-Host $taskExists.State -ForegroundColor Yellow
        }
        
        # Last run time
        if ($taskInfo.LastRunTime) {
            $lastRunTime = $taskInfo.LastRunTime
            $timeSpan = (Get-Date) - $lastRunTime
            
            Write-Host "Last Run:   " -NoNewline -ForegroundColor White
            Write-Host "$lastRunTime " -NoNewline -ForegroundColor Yellow
            
            if ($timeSpan.TotalDays -ge 1) {
                Write-Host "($([math]::Round($timeSpan.TotalDays, 1)) days ago)" -ForegroundColor Yellow
            }
            elseif ($timeSpan.TotalHours -ge 1) {
                Write-Host "($([math]::Round($timeSpan.TotalHours, 1)) hours ago)" -ForegroundColor Yellow
            }
            else {
                Write-Host "($([math]::Round($timeSpan.TotalMinutes, 1)) minutes ago)" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "Last Run:   " -NoNewline -ForegroundColor White
            Write-Host "Never" -ForegroundColor Red
        }
        
        # Next run time
        if ($taskInfo.NextRunTime) {
            $nextRunTime = $taskInfo.NextRunTime
            $timeSpan = $nextRunTime - (Get-Date)
            
            Write-Host "Next Run:   " -NoNewline -ForegroundColor White
            Write-Host "$nextRunTime " -NoNewline -ForegroundColor Yellow
            
            if ($timeSpan.TotalDays -ge 1) {
                Write-Host "(in $([math]::Round($timeSpan.TotalDays, 1)) days)" -ForegroundColor Yellow
            }
            elseif ($timeSpan.TotalHours -ge 1) {
                Write-Host "(in $([math]::Round($timeSpan.TotalHours, 1)) hours)" -ForegroundColor Yellow
            }
            else {
                Write-Host "(in $([math]::Round($timeSpan.TotalMinutes, 1)) minutes)" -ForegroundColor Yellow
            }
        }
        else {
            Write-Host "Next Run:   " -NoNewline -ForegroundColor White
            Write-Host "Not scheduled" -ForegroundColor Red
        }
        
        # Last result
        Write-Host "Last Result: " -NoNewline -ForegroundColor White
        if ($taskInfo.LastTaskResult -eq 0) {
            Write-Host "Success (0)" -ForegroundColor Green
        }
        else {
            Write-Host "Error ($($taskInfo.LastTaskResult))" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Task not installed" -ForegroundColor Red
        Write-Host "Use option 2 from the main menu to install the scheduled task." -ForegroundColor Yellow
    }
} 