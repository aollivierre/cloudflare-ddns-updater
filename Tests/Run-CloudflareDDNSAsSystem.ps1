# Run-CloudflareDDNSAsSystem.ps1
# This script runs the Cloudflare DDNS update script as SYSTEM using the AsSystem module

# Import the AsSystem module (adjust path if needed)
$asSystemModulePath = "C:\code\modulesv2\AsSystem-Module\AsSystem"
if (!(Test-Path -Path $asSystemModulePath)) {
    Write-Host "AsSystem module not found at $asSystemModulePath" -ForegroundColor Red
    Write-Host "Please update the `$asSystemModulePath variable to point to the correct location" -ForegroundColor Yellow
    exit 1
}

# Import the module
Write-Host "Importing AsSystem module from $asSystemModulePath" -ForegroundColor Cyan
Import-Module -Name $asSystemModulePath -Force

# Path to the Cloudflare DDNS update script
$scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Update-CloudflareDNS.ps1"
if (!(Test-Path -Path $scriptPath)) {
    Write-Host "Cloudflare DDNS update script not found at $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "Found Cloudflare DDNS update script at $scriptPath" -ForegroundColor Green

# Check if we're already running as SYSTEM
$runningAsSystem = Test-RunningAsSystem
if ($runningAsSystem) {
    Write-Host "Already running as SYSTEM, executing script directly" -ForegroundColor Yellow
    & $scriptPath
    exit 0
}

# Prepare to run as SYSTEM
Write-Host "Executing Cloudflare DDNS update script as SYSTEM..." -ForegroundColor Yellow

# Run the script as SYSTEM
$result = Invoke-ScriptAsSystem -ScriptPath $scriptPath -Verbose

if ($result) {
    Write-Host "Cloudflare DDNS update was executed successfully as SYSTEM" -ForegroundColor Green
    
    # Check SYSTEM temp directory for error logs
    $systemTempDir = "C:\Windows\System32\config\systemprofile\AppData\Local\Temp"
    $errorLogs = Get-ChildItem -Path $systemTempDir -Filter "cloudflare_ddns_error.log" -ErrorAction SilentlyContinue
    
    if ($errorLogs.Count -gt 0) {
        Write-Host "Found error logs in SYSTEM temp directory:" -ForegroundColor Red
        foreach ($log in $errorLogs) {
            Write-Host "- $($log.FullName)" -ForegroundColor Red
            Write-Host "  Content: $(Get-Content -Path $log.FullName -Raw)" -ForegroundColor Gray
        }
    }
    
    # Check the main log file
    $logPath = "C:\ProgramData\CloudflareDDNS\logs\cloudflare_ddns.log"
    if (Test-Path -Path $logPath) {
        Write-Host "Log file created at $logPath" -ForegroundColor Green
        Write-Host "Last 10 log entries:" -ForegroundColor Cyan
        Get-Content -Path $logPath -Tail 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "No log file found at $logPath" -ForegroundColor Red
    }
} else {
    Write-Host "Failed to execute Cloudflare DDNS update as SYSTEM" -ForegroundColor Red
} 