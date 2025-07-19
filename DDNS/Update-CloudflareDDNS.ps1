#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Updates Cloudflare DNS records with your current public IP address.
.DESCRIPTION
    This script retrieves your current public IP address and updates a specified Cloudflare DNS record when changes are detected.
    It can be run manually or as a scheduled task to keep your dynamic DNS records up to date.
.PARAMETER Silent
    Runs the script without interactive menus, just performing the DNS update operation
.PARAMETER InstallTask
    Installs a scheduled task to run the script periodically
.PARAMETER ShowLog
    Shows the log file
.PARAMETER ClearLog
    Clears the log files
.PARAMETER ShowWindow
    When used in a scheduled task, keeps the window open after running to display results
.PARAMETER ForceDirect
    Used for direct execution from Task Scheduler to ensure proper logging
.PARAMETER LogFile
    Explicitly specifies the log file path to use
.EXAMPLE
    .\Update-CloudflareDDNS.ps1
    Launches the interactive menu.
.EXAMPLE
    .\Update-CloudflareDDNS.ps1 -Silent
    Updates the DNS record without showing the menu.
.EXAMPLE
    .\Update-CloudflareDDNS.ps1 -InstallTask
    Installs a scheduled task to update DNS records regularly.
.EXAMPLE
    .\Update-CloudflareDDNS.ps1 -Silent -LogFile "C:\ProgramData\CloudflareDDNS\logs\CloudflareDDNS.log"
    Updates the DNS record and logs activity to the specified file.
.NOTES
    Author: Your Name
    Version: 2.0
#>

[CmdletBinding(DefaultParameterSetName = 'Operation')]
param(
    [Parameter(ParameterSetName = 'Operation')]
    [switch]$Silent,
    
    [Parameter(ParameterSetName = 'Install')]
    [switch]$InstallTask,
    
    [Parameter(ParameterSetName = 'Operation')]
    [switch]$ShowLog,
    
    [Parameter(ParameterSetName = 'Operation')]
    [switch]$ClearLog,
    
    [Parameter(ParameterSetName = 'Operation')]
    [switch]$ForceUpdate,
    
    [Parameter(ParameterSetName = 'Operation')]
    [switch]$ShowWindow,
    
    [Parameter(ParameterSetName = 'Operation')]
    [switch]$ForceDirect,
    
    [Parameter(ParameterSetName = 'Operation')]
    [string]$LogFile,
    
    [Parameter(ParameterSetName = 'SystemOps')]
    [string]$ExportConfigAsSystem,
    
    [Parameter(ParameterSetName = 'SystemOps')]
    [switch]$ImportConfigAsSystem,
    
    [Parameter(ParameterSetName = 'SystemOps')]
    [switch]$ConfigureAsSystem,
    
    [Parameter(ParameterSetName = 'SystemOps')]
    [string]$ApiToken,
    
    [Parameter(ParameterSetName = 'SystemOps')]
    [string]$ZoneId,
    
    [Parameter(ParameterSetName = 'SystemOps')]
    [string]$Domain,
    
    [Parameter(ParameterSetName = 'SystemOps')]
    [string]$HostName
)

# Import the module - first try from installed modules, then try from the local path
$moduleImported = $false

# Try to import the module from the PSModulePath
try {
    Import-Module -Name CloudflareDDNS -DisableNameChecking -ErrorAction Stop
    $moduleImported = $true
    Write-Verbose "Module imported from PSModulePath"
}
catch {
    Write-Verbose "Module not found in PSModulePath: $_"
    # If that fails, try to import from the script directory
    try {
        $moduleLocation = Join-Path -Path $PSScriptRoot -ChildPath "CloudflareDDNS"
        if (Test-Path -Path $moduleLocation) {
            Import-Module -Name $moduleLocation -DisableNameChecking -ErrorAction Stop
            $moduleImported = $true
            Write-Verbose "Module imported from script directory"
        }
        else {
            # Try one level up (if we're in the "DDNS" subdirectory)
            $moduleLocationParent = Join-Path -Path (Split-Path -Parent $PSScriptRoot) -ChildPath "CloudflareDDNS"
            if (Test-Path -Path $moduleLocationParent) {
                Import-Module -Name $moduleLocationParent -DisableNameChecking -ErrorAction Stop
                $moduleImported = $true
                Write-Verbose "Module imported from parent directory"
            }
        }
    }
    catch {
        Write-Verbose "Failed to import from local path: $_"
    }
}

if (-not $moduleImported) {
    Write-Error "Failed to import CloudflareDDNS module. Make sure it's installed or located in the same directory as this script."
    exit 1
}

# Handle parameters
if ($InstallTask) {
    Install-CloudflareDDNSTask
    exit
}

if ($ShowLog) {
    Show-CloudflareDDNSLog
    exit
}

if ($ClearLog) {
    Clear-CloudflareDDNSLog
    exit
}

if ($ExportConfigAsSystem) {
    # This is a system-level request to export config
    Write-Verbose "Exporting configuration as SYSTEM"
    # You'd need to implement this in your module
    exit
}

if ($ImportConfigAsSystem) {
    # This is a system-level request to import config
    Write-Verbose "Importing configuration as SYSTEM"
    # You'd need to implement this in your module
    exit
}

if ($ConfigureAsSystem) {
    # This is a system-level request to configure
    Write-Verbose "Configuring as SYSTEM"
    $params = @{}
    if ($ApiToken) { $params['ApiToken'] = $ApiToken }
    if ($ZoneId) { $params['ZoneId'] = $ZoneId }
    if ($Domain) { $params['Domain'] = $Domain }
    if ($HostName) { $params['HostName'] = $HostName }
    $params['AsSystem'] = $true
    
    Configure-CloudflareAPIToken @params
    exit
}

if ($Silent) {
    # Run the update in silent mode for scheduled tasks or command-line runs
    $updateParams = @{}
    if ($ForceUpdate) { $updateParams['Force'] = $true }
    if ($ForceDirect) { $updateParams['ForceDirect'] = $true }
    if ($LogFile) { $updateParams['LogFile'] = $LogFile }
    
    $updateResult = Update-CloudflareDNSRecord @updateParams
    
    # Keep the window open if requested
    if ($ShowWindow) {
        Write-Host "`nPress Enter to close this window..." -ForegroundColor Cyan
        Read-Host
    }
    
    exit
}
else {
    # Interactive mode - show menu
    Show-CloudflareDDNSMenu
} 