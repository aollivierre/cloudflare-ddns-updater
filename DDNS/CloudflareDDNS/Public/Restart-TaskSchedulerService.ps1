function Restart-TaskSchedulerService {
    [CmdletBinding()]
    param(
        [Parameter(HelpMessage = "Set to true to allow system reboot")]
        [bool]$AllowReboot = $false
    )
    
    Write-Host ""
    Write-Host "Task Scheduler Service Restart Required" -ForegroundColor Cyan
    Write-CloudflareDDNSLog -Message "Task Scheduler service restart requested" -Status "INFO" -Color "White"
    
    try {
        # Check if running as admin
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Host "This operation requires administrator privileges." -ForegroundColor Red
            Write-Host "Please run this script as an administrator." -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "Insufficient privileges for Task Scheduler service operation" -Status "ERROR" -Color "Red"
            return $false
        }
        
        # Check Task Scheduler service status
        $scheduleService = Get-Service -Name "Schedule" -ErrorAction SilentlyContinue
        
        if ($scheduleService) {
            Write-Host ""
            Write-Host "IMPORTANT: The Task Scheduler service cannot be restarted while Windows is running." -ForegroundColor Yellow
            Write-Host "A system reboot is required to fully restart this service." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "Troubleshooting suggestions:" -ForegroundColor Cyan
            Write-Host "1. Check if the Task Scheduler service is running" -ForegroundColor White
            Write-Host "2. Verify that you have proper permissions" -ForegroundColor White
            Write-Host "3. Review any dependent services that might be causing issues" -ForegroundColor White
            Write-Host "4. Reboot the system to fully restart the Task Scheduler service" -ForegroundColor White
            Write-Host ""
            
            Write-CloudflareDDNSLog -Message "Task Scheduler service cannot be restarted without system reboot" -Status "WARNING" -Color "Yellow"
            
            if ($AllowReboot) {
                $confirmation = Read-Host "Do you want to reboot the system now? (Y/N)"
                if ($confirmation -eq 'Y' -or $confirmation -eq 'y') {
                    Write-Host "Initiating system reboot..." -ForegroundColor Red
                    Write-CloudflareDDNSLog -Message "System reboot initiated to restart Task Scheduler service" -Status "WARNING" -Color "Yellow"
                    
                    # Schedule a system reboot
                    Restart-Computer -Force
                    return $true
                }
                else {
                    Write-Host "System reboot cancelled by user." -ForegroundColor Yellow
                    Write-CloudflareDDNSLog -Message "System reboot cancelled by user" -Status "INFO" -Color "White"
                    return $false
                }
            }
            else {
                Write-Host "To reboot the system, run this function with -AllowReboot `$true parameter" -ForegroundColor Yellow
                return $false
            }
        }
        else {
            Write-Host "Task Scheduler service not found on this system." -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "Task Scheduler service not found" -Status "ERROR" -Color "Red"
            return $false
        }
    }
    catch {
        Write-Host "Error while checking Task Scheduler service: $_" -ForegroundColor Red
        Write-CloudflareDDNSLog -Message "Error checking Task Scheduler service: $_" -Status "ERROR" -Color "Red"
        return $false
    }
}