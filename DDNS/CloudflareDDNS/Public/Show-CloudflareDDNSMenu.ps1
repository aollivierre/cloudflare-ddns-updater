function Show-CloudflareDDNSMenu {
    # Clear-Host
    
    # Define module paths to check for AsSystem
    $customModulePaths = @(
        "C:\code\Modulesv2\AsSystem-Module\AsSystem\AsSystem.psd1",
        "$script:ModuleRoot\Modules\AsSystem\AsSystem.psd1",
        "$env:ProgramData\AsSystem\AsSystem.psd1"
    )
    
    # Check if AsSystem is available
    $asSystemAvailable = $false
    
    # Check if already loaded
    if (Get-Module -Name AsSystem) {
        $asSystemAvailable = $true
    }
    # Check standard paths
    elseif (Get-Module -ListAvailable -Name AsSystem) {
        $asSystemAvailable = $true
        Import-Module -Name AsSystem -DisableNameChecking
        Write-Host "AsSystem module loaded successfully." -ForegroundColor Green
    }
    # Check custom paths
    else {
        foreach ($modulePath in $customModulePaths) {
            if (Test-Path -Path $modulePath) {
                try {
                    Import-Module -Name $modulePath -DisableNameChecking -ErrorAction Stop
                    $asSystemAvailable = $true
                    Write-Host "AsSystem module loaded successfully." -ForegroundColor Green
                    break
                }
                catch {
                    Write-Host "Failed to import AsSystem module from $modulePath" -ForegroundColor Yellow
                }
            }
        }
    }
    
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "    CLOUDFLARE DDNS UPDATER" -ForegroundColor White
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host " This tool updates Cloudflare DNS records" -ForegroundColor White
    Write-Host " when your public IP address changes." -ForegroundColor White
    Write-Host ""
    Write-Host " Select an option:" -ForegroundColor White
    Write-Host ""
    Write-Host " 1: Update DNS record now" -ForegroundColor Green
    Write-Host " 2: Install scheduled task" -ForegroundColor Green
    Write-Host " 3: View log file" -ForegroundColor Yellow
    Write-Host " 4: Clear log file" -ForegroundColor Yellow
    Write-Host " 5: View/Edit configuration" -ForegroundColor Cyan
    Write-Host " 6: Open Task Scheduler" -ForegroundColor Magenta
    Write-Host " 7: Remove scheduled task" -ForegroundColor Red
    Write-Host " 8: Run scheduled task" -ForegroundColor Green
    Write-Host " 9: Test API connection" -ForegroundColor Cyan
    Write-Host "10: Show current status" -ForegroundColor Cyan
    Write-Host "11: Enable/Disable task" -ForegroundColor Cyan
    Write-Host "12: Restart Task Scheduler service" -ForegroundColor Magenta
    
    # Show option 13 if AsSystem is available
    if ($asSystemAvailable) {
        # Use Silent options to suppress all output including Verbose messages
        $isSystem = $false
        if (Get-Command -Name Test-RunningAsSystem -ErrorAction SilentlyContinue) {
            # Temporarily set VerbosePreference to SilentlyContinue
            $originalVerbosePreference = $VerbosePreference
            $VerbosePreference = 'SilentlyContinue'
            
            # Execute command with all output suppressed
            $isSystem = Test-RunningAsSystem -WarningAction SilentlyContinue -Verbose:$false 2>$null 3>$null 4>$null 5>$null 6>$null
            
            # Restore original preference
            $VerbosePreference = $originalVerbosePreference
        }
        
        if (-not $isSystem) {
            Write-Host "13: Configure as SYSTEM account" -ForegroundColor Yellow
        }
    }
    
    Write-Host " Q: Quit" -ForegroundColor Red
    Write-Host ""
    
    $selection = Read-Host "Enter your choice (1-13 or Q)"
    
    switch ($selection.ToUpper()) {
        "1" {
            Write-Host ""
            Write-Host "Updating DNS record..." -ForegroundColor Cyan
            $updateResult = Update-CloudflareDNSRecord -UseConsoleLog
            # Result is displayed by the function now with enhanced feedback
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "2" { 
            Install-CloudflareDDNSTask
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "3" { 
            Show-CloudflareDDNSLog
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "4" { 
            Clear-CloudflareDDNSLog
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "5" { 
            Edit-CloudflareConfig
            Show-CloudflareDDNSMenu
        }
        "6" { 
            Start-Process "taskschd.msc"
            Show-CloudflareDDNSMenu
        }
        "7" { 
            Remove-CloudflareDDNSTask
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "8" { 
            Run-CloudflareDDNSTask
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "9" { 
            Test-CloudflareAPIConnection
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "10" { 
            Show-CloudflareDDNSStatus
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "11" {
            Toggle-CloudflareDDNSTask
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "12" {
            # Call the dedicated function to restart the Task Scheduler service
            Restart-TaskSchedulerService
            
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "13" {
            if ($asSystemAvailable) {
                # Use Silent options to suppress all output including Verbose messages
                $isSystem = $false
                if (Get-Command -Name Test-RunningAsSystem -ErrorAction SilentlyContinue) {
                    # Temporarily set VerbosePreference to SilentlyContinue
                    $originalVerbosePreference = $VerbosePreference
                    $VerbosePreference = 'SilentlyContinue'
                    
                    # Execute command with all output suppressed
                    $isSystem = Test-RunningAsSystem -WarningAction SilentlyContinue -Verbose:$false 2>$null 3>$null 4>$null 5>$null 6>$null
                    
                    # Restore original preference
                    $VerbosePreference = $originalVerbosePreference
                }
                
                if (-not $isSystem) {
                    Configure-CloudflareAPIToken
                    Write-Host ""
                    Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
                    Read-Host
                }
            }
            Show-CloudflareDDNSMenu
        }
        "Q" { return }
        default { 
            Write-Host "Invalid selection. Please try again." -ForegroundColor Red
            Start-Sleep -Seconds 2
            Show-CloudflareDDNSMenu
        }
    }
} 