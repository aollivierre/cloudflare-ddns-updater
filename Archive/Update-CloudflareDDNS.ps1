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
    Version: 1.0
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

# Default configuration - will be overridden by external config file if it exists
$defaultConfig = @{
    ZoneId            = "your-zone-id"
    ApiToken          = "your-api-token"
    Domain            = "yourdomain.com"
    HostName          = "subdomain"
    TTL               = 120
    LogDir            = "$env:ProgramData\CloudflareDDNS"
    ConfigDir         = "$env:ProgramData\CloudflareDDNS"
    EncryptionEnabled = $true
}

# Global variables - don't modify
$ConfigFileName = "CloudflareDDNS-Config.json"
$EncryptedConfigFileName = "CloudflareDDNS-Config.secure"
$Config = $null
$LogFile = $null
$TaskLogFile = $null
$global:ConfigNeedsToken = $false

# Initialize configuration
function Initialize-CloudflareDDNSConfig {
    [CmdletBinding()]
    param(
        [switch]$NoPrompt
    )
    
    # Initialize the global variable
    $global:ConfigNeedsToken = $false
    
    # Load Config Directory
    $configDir = Join-Path -Path $PSScriptRoot -ChildPath "config"
    if (-not (Test-Path -Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    # Filenames
    $configPath = Join-Path -Path $configDir -ChildPath $ConfigFileName
    $secureConfigPath = Join-Path -Path $configDir -ChildPath $EncryptedConfigFileName
    
    # Default configuration
    $config = @{
        ConfigDir         = $configDir
        ZoneId            = "YOUR_ZONE_ID"
        ApiToken          = "API_TOKEN_PLACEHOLDER"
        Domain            = "yourdomain.com"
        Hostname          = "hostname"
        TTL               = 120
        EncryptionEnabled = $true
        LastIp            = ""
        LastUpdate        = ""
        LogDir            = Join-Path -Path $configDir -ChildPath "logs"
    }
    
    # Check for secure config first
    if (Test-Path -Path $secureConfigPath) {
        try {
            $secureConfig = Import-Clixml -Path $secureConfigPath
            $config["ZoneId"] = $secureConfig.ZoneId
            # Attempt to decrypt the API token
            try {
                $apiTokenBytes = $secureConfig.ApiToken | ConvertFrom-SecureString -AsPlainText
                $config["ApiToken"] = $apiTokenBytes
            }
            catch {
                # If decryption fails, mark as placeholder
                $config["ApiToken"] = "ENCRYPTED - SEE SECURE CONFIG FILE"
                Write-CloudflareDDNSLog -Message "Failed to decrypt API token from secure storage. $($_.Exception.Message)" -Status "WARNING" -Color "Yellow"
            }
            
            $config["Domain"] = $secureConfig.Domain
            $config["Hostname"] = $secureConfig.Hostname
            $config["TTL"] = $secureConfig.TTL
            $config["EncryptionEnabled"] = $true
            $config["LastIp"] = $secureConfig.LastIp
            $config["LastUpdate"] = $secureConfig.LastUpdate
            if ($secureConfig.LogDir) {
                $config["LogDir"] = $secureConfig.LogDir
            }
            
            Write-CloudflareDDNSLog -Message "Loaded secure configuration from $secureConfigPath" -Status "SUCCESS" -Color "Green"
        }
        catch {
            Write-CloudflareDDNSLog -Message "Failed to load secure configuration: $_" -Status "ERROR" -Color "Red"
        }
    }
    # Check for regular config
    elseif (Test-Path -Path $configPath) {
        try {
            $fileConfig = Get-Content -Path $configPath -Raw | ConvertFrom-Json
            
            # Convert PSCustomObject to hashtable
            foreach ($prop in $fileConfig.PSObject.Properties) {
                $config[$prop.Name] = $prop.Value
            }
            
            # Ensure ConfigDir is set
            $config["ConfigDir"] = $configDir
            
            # Ensure LogDir exists
            if (-not $config.ContainsKey("LogDir")) {
                $config["LogDir"] = Join-Path -Path $configDir -ChildPath "logs"
            }
            
            # Set EncryptionEnabled to false since we're using JSON config
            $config["EncryptionEnabled"] = $false
            
            Write-CloudflareDDNSLog -Message "Loaded configuration from $configPath" -Status "SUCCESS" -Color "Green"
        }
        catch {
            Write-CloudflareDDNSLog -Message "Failed to load configuration from $configPath $_" -Status "ERROR" -Color "Red"
        }
    }
    else {
        # No config exists, create a new one
        $config | ConvertTo-Json | Set-Content -Path $configPath -Force
        Write-CloudflareDDNSLog -Message "Created new configuration file at $configPath" -Status "INFO" -Color "Cyan"
    }
    
    # Check if API token is a placeholder or missing
    if ($Config["ApiToken"] -eq "ENCRYPTED - SEE SECURE CONFIG FILE" -or 
        $Config["ApiToken"] -eq "API_TOKEN_PLACEHOLDER" -or
        $Config["ApiToken"] -eq "YOUR_API_TOKEN" -or
        $Config["ApiToken"] -eq "your-api-token") {
        
        # Set the global flag that we need a token
        $global:ConfigNeedsToken = $true
        
        # Only prompt for token if NoPrompt is not specified
        if (-not $NoPrompt) {
            Write-Host ""
            Write-Host "Your API Token is missing or could not be decrypted." -ForegroundColor Red
            Write-Host "Please enter your Cloudflare API Token now:" -ForegroundColor Yellow
            $newApiToken = Read-Host -AsSecureString "API Token"
            
            if ($newApiToken.Length -gt 0) {
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($newApiToken)
                $Config["ApiToken"] = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
                $global:ConfigNeedsToken = $false
                
                # Save the updated config
                if ($Config["EncryptionEnabled"]) {
                    Export-CloudflareDDNSSecureConfig -Config $Config
                    Write-Output "Saved new API token to secure configuration."
                }
                else {
                    # Save to regular config
                    $Config | ConvertTo-Json | Set-Content -Path $configPath -Force
                    Write-Output "Saved new API token to configuration."
                }
            }
            else {
                Write-Host "No API token provided. Some operations may fail." -ForegroundColor Red
                # Keep the placeholder token
            }
        }
    }
    
    return $config
}

# Export encrypted config file
function Export-CloudflareDDNSSecureConfig {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Config
    )
    
    # Check if running as SYSTEM, if not, try to elevate
    if (-not (Test-RunningAsSystem)) {
        return Invoke-ConfigOperationAsSystem -Operation "Export" -Config $Config
    }
    
    $encryptedConfigPath = Join-Path -Path $Config['ConfigDir'] -ChildPath $EncryptedConfigFileName
    
    try {
        # Create a copy of the config object for encryption
        $configToExport = @{}
        foreach ($key in $Config.Keys) {
            $configToExport[$key] = $Config[$key]
        }
        
        # Convert sensitive values to SecureString
        if ($Config['ApiToken']) {
            $secureApiToken = ConvertTo-SecureString -String $Config['ApiToken'] -AsPlainText -Force
            $configToExport['ApiToken'] = $secureApiToken | ConvertFrom-SecureString
        }
        
        # Export to file
        $configToExport | ConvertTo-Json | Set-Content -Path $encryptedConfigPath -Force
        return $true
    }
    catch {
        Write-Error "Failed to export secure configuration: $_"
        return $false
    }
}

# Import encrypted config file
function Import-CloudflareDDNSSecureConfig {
    # Check if running as SYSTEM, if not, try to elevate
    if (-not (Test-RunningAsSystem)) {
        return Invoke-ConfigOperationAsSystem -Operation "Import"
    }
    
    $encryptedConfigPath = Join-Path -Path $defaultConfig.ConfigDir -ChildPath $EncryptedConfigFileName
    
    if (-not (Test-Path $encryptedConfigPath)) {
        Write-Error "Secure configuration file not found"
        return $null
    }
    
    try {
        # Load the encrypted config
        $encryptedConfig = Get-Content -Path $encryptedConfigPath -Raw | ConvertFrom-Json
        
        # Convert to hashtable
        $configHashtable = @{}
        foreach ($property in $encryptedConfig.PSObject.Properties) {
            $configHashtable[$property.Name] = $property.Value
        }
        
        # Decrypt sensitive values
        if ($configHashtable.ApiToken) {
            try {
                $secureString = $configHashtable.ApiToken | ConvertTo-SecureString -ErrorAction Stop
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
                $configHashtable.ApiToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
            }
            catch {
                Write-Warning "Could not decrypt API token. This typically happens when:"
                Write-Warning "- Configuration was created on a different machine"
                Write-Warning "- Configuration was created by a different user account"
                Write-Warning "- Encrypted data is corrupted"
                Write-Warning "Removing secure config file and falling back to standard configuration..."
                
                # Rename the problematic secure config file
                $backupPath = "$encryptedConfigPath.backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
                Rename-Item -Path $encryptedConfigPath -NewName $backupPath -Force
                
                # Return null to trigger fallback to standard config
                return $null
            }
        }
        
        return $configHashtable
    }
    catch {
        Write-Error "Failed to import secure configuration: $_"
        return $null
    }
}

# Function to check if running as SYSTEM account
function Test-RunningAsSystem {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
    
    # Check if running as SYSTEM account
    if ($currentUser.User.Value -eq "S-1-5-18") {
        return $true
    }
    
    # If using AsSystem module, also check its function
    if (Get-Command -Name Test-AsSystem -ErrorAction SilentlyContinue) {
        $isSystem = Test-AsSystem
        if ($isSystem) {
            return $true
        }
    }
    
    # Verbose logging
    Write-Verbose "[Test-RunningAsSystem] [WARNING] The script is not running under the SYSTEM account."
    return $false
}

# Function to execute configuration operations as SYSTEM
function Invoke-ConfigOperationAsSystem {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet("Export", "Import", "Configure")]
        [string]$Operation,
        
        [Parameter()]
        [object]$Config = $null,
        
        [Parameter()]
        [hashtable]$Parameters = @{}
    )
    
    # Define custom module paths to check
    $customModulePaths = @(
        "C:\code\Modulesv2\AsSystem-Module\AsSystem",
        "$PSScriptRoot\Modules\AsSystem",
        "$env:ProgramData\AsSystem"
    )
    
    # Variable to track if module was found
    $moduleFound = $false
    
    # Check if AsSystem module is already loaded
    if (Get-Module -Name AsSystem) {
        $moduleFound = $true
        Write-Host "AsSystem module already loaded." -ForegroundColor Green
    }
    # Check custom paths
    else {
        foreach ($path in $customModulePaths) {
            $modulePath = Join-Path -Path $path -ChildPath "AsSystem.psd1"
            if (Test-Path -Path $modulePath) {
                try {
                    Import-Module -Name $modulePath -ErrorAction Stop
                    $moduleFound = $true
                    Write-Host "AsSystem module found and imported from: $modulePath" -ForegroundColor Green
                    break
                }
                catch {
                    Write-Host "Found module at $modulePath but could not import it: $_" -ForegroundColor Yellow
                }
            }
        }
    }
    
    # If module is still not found
    if (-not $moduleFound) {
        Write-Host "AsSystem module not found. Encrypted configuration requires System account access." -ForegroundColor Yellow
        Write-Host "AsSystem module was not found in standard PowerShell module paths or any of:" -ForegroundColor Yellow
        foreach ($path in $customModulePaths) {
            Write-Host "  - $path" -ForegroundColor Yellow
        }
        Write-Host "You can either:" -ForegroundColor Yellow
        Write-Host "1. Install the AsSystem module to enable SYSTEM-level encryption" -ForegroundColor Yellow
        Write-Host "2. Use plaintext configuration (less secure)" -ForegroundColor Yellow
        
        $choice = Read-Host "Would you like to disable encryption and continue with plaintext? (Y/N)"
        
        if ($choice.ToUpper() -eq 'Y') {
            # Disable encryption
            if ($Config) {
                $Config['EncryptionEnabled'] = $false
                $configPath = Join-Path -Path $Config.ConfigDir -ChildPath $ConfigFileName
                $Config | ConvertTo-Json | Set-Content -Path $configPath -Force
                Write-Host "Encryption has been disabled. Using plaintext configuration." -ForegroundColor Yellow
                return $true
            }
            else {
                return $null
            }
        }
        else {
            Write-Host "Operation cancelled. Please install the AsSystem module and try again." -ForegroundColor Red
            return $false
        }
    }
    
    try {
        # Get script path
        $scriptPath = $MyInvocation.MyCommand.Path
        if (-not $scriptPath) {
            $scriptPath = $PSCommandPath
        }
        if (-not $scriptPath) {
            $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Update-CloudflareDDNS.ps1"
        }
        
        # Create a temporary script file that will run our script with the desired parameters
        $tempScriptPath = Join-Path -Path $env:TEMP -ChildPath "CloudflareDDNS_AsSystem_$([Guid]::NewGuid().ToString()).ps1"
        
        # Define the contents of the temporary script
        $scriptContent = @"
# Temporary script to run DDNS script as SYSTEM
`$ErrorActionPreference = 'Continue'
`$VerbosePreference = 'Continue'

# Run the main script with appropriate parameters
"@
        
        # Add appropriate parameters based on operation
        switch ($Operation) {
            "Export" {
                # We need to serialize the configuration to pass it
                $tempConfigPath = Join-Path -Path $env:TEMP -ChildPath "CloudflareDDNS_TempConfig.json"
                $Config | ConvertTo-Json -Depth 10 | Set-Content -Path $tempConfigPath -Force
                
                $scriptContent += @"

# Execute main script with ExportConfigAsSystem parameter
& "$scriptPath" -ExportConfigAsSystem "$tempConfigPath"
exit `$LASTEXITCODE
"@
            }
            "Import" {
                $scriptContent += @"

# Execute main script with ImportConfigAsSystem parameter
& "$scriptPath" -ImportConfigAsSystem
exit `$LASTEXITCODE
"@
            }
            "Configure" {
                $scriptContent += @"

# Execute main script with ConfigureAsSystem parameter
& "$scriptPath" -ConfigureAsSystem
"@
                
                # Add any additional parameters
                foreach ($key in $Parameters.Keys) {
                    $paramValue = $Parameters[$key]
                    $scriptContent += " -$key `"$paramValue`""
                }
                
                $scriptContent += @"

exit `$LASTEXITCODE
"@
            }
        }
        
        # Write the temporary script to disk
        $scriptContent | Out-File -FilePath $tempScriptPath -Encoding UTF8 -Force
        
        Write-Host "Created temporary script at: $tempScriptPath" -ForegroundColor Cyan
        
        # Launch the script as SYSTEM using appropriate function from AsSystem module
        if (Get-Command -Name Invoke-ScriptAsSystem -ErrorAction SilentlyContinue) {
            Write-Host "Using Invoke-ScriptAsSystem to run as SYSTEM account..." -ForegroundColor Cyan
            $result = Invoke-ScriptAsSystem -ScriptPath $tempScriptPath
        }
        elseif (Get-Command -Name Invoke-AsSystem -ErrorAction SilentlyContinue) {
            # Fall back to Invoke-AsSystem if available
            Write-Host "Using Invoke-AsSystem to run as SYSTEM account..." -ForegroundColor Cyan
            $result = Invoke-AsSystem -ScriptPathAsSYSTEM $tempScriptPath
        }
        else {
            Write-Host "Cannot find appropriate function in AsSystem module to run as SYSTEM." -ForegroundColor Red
            throw "AsSystem module functions not available"
        }
        
        # Clean up temp files
        if (Test-Path $tempScriptPath) {
            Remove-Item -Path $tempScriptPath -Force -ErrorAction SilentlyContinue
        }
        
        if ($Operation -eq "Export" -and (Test-Path $tempConfigPath)) {
            Remove-Item -Path $tempConfigPath -Force -ErrorAction SilentlyContinue
        }
        
        return $result
    }
    catch {
        Write-Error "Failed to run as SYSTEM: $_"
        return $false
    }
}

#region Functions
function Write-CloudflareDDNSLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [string]$Status = "INFO",
        
        [Parameter(Mandatory = $false)]
        [string]$Color = "White",
        
        [Parameter(Mandatory = $false)]
        [string]$LogFilePath = ""
    )
    
    # If no explicit log path is provided, use the global log file
    if ([string]::IsNullOrEmpty($LogFilePath)) {
        $LogFilePath = $script:LogFile
    }
    
    # Get identity for context-aware logging
    try {
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    } catch {
        $currentUser = "Unknown"
    }
    
    # Format the log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$currentUser] [$Status] $Message"
    
    # Write to the log file
    if (![string]::IsNullOrEmpty($LogFilePath)) {
        try {
            # Ensure the directory exists
            $logDir = Split-Path -Path $LogFilePath -Parent
            if (![string]::IsNullOrEmpty($logDir) -and !(Test-Path -Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            
            # Add the log entry
            $logEntry | Out-File -FilePath $LogFilePath -Append
        }
        catch {
            # If we can't write to the log, at least try to display the error
            Write-Error "Failed to write to log $LogFilePath. Error: $($_.Exception.Message)"
        }
    }
}

function Show-CloudflareDDNSMenu {
    # Clear-Host
    
    # Define module paths to check for AsSystem
    $customModulePaths = @(
        "C:\code\Modulesv2\AsSystem-Module\AsSystem\AsSystem.psd1",
        "$PSScriptRoot\Modules\AsSystem\AsSystem.psd1",
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
        Import-Module -Name AsSystem
        Write-Host "AsSystem module loaded successfully." -ForegroundColor Green
    }
    # Check custom paths
    else {
        foreach ($modulePath in $customModulePaths) {
            if (Test-Path -Path $modulePath) {
                try {
                    Import-Module -Name $modulePath -ErrorAction Stop
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
    Write-Host "12: Run diagnostics" -ForegroundColor Magenta
    
    # Show option 13 if AsSystem is available and not running as SYSTEM
    if ($asSystemAvailable -and -not (Test-RunningAsSystem)) {
        Write-Host "13: Configure as SYSTEM account" -ForegroundColor Yellow
    }
    
    Write-Host " Q: Quit" -ForegroundColor Red
    Write-Host ""
    
    $selection = Read-Host "Enter your choice (1-13 or Q)"
    
    switch ($selection.ToUpper()) {
        "1" { 
            Update-CloudflareDNSRecord -UseConsoleLog
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
            Edit-Config
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
            Run-CloudflareDDNSDiagnostics
            Write-Host ""
            Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
            Read-Host
            Show-CloudflareDDNSMenu
        }
        "13" { 
            if ($asSystemAvailable -and -not (Test-RunningAsSystem)) {
                Configure-AsSystemAccount
                Write-Host ""
                Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
                Read-Host
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

function Get-PublicIP {
    [CmdletBinding()]
    param()
    
    $ipServices = @(
        "https://api.ipify.org",
        "https://ifconfig.me/ip",
        "https://icanhazip.com",
        "https://wtfismyip.com/text",
        "https://api.ipify.org?format=text",
        "https://checkip.amazonaws.com"
    )
    
    foreach ($service in $ipServices) {
        try {
            $ip = Invoke-RestMethod -Uri $service -TimeoutSec 5
            if ($ip -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                Write-CloudflareDDNSLog -Message "Detected public IP $ip" -LogFilePath $script:LogFile
                return $ip.Trim()
            }
        }
        catch {
            # Continue to the next service
        }
    }
    
    # If all services fail, log the error
    Write-CloudflareDDNSLog -Message "ERROR: Failed to get public IP $_" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
    return $null
}

function Get-CloudflareRecord {
    [CmdletBinding()]
    param()
    
    try {
        # Load configuration
        $apiToken = $Config['APIToken']
        $zoneID = $Config['ZoneID']
        $recordType = $Config['RecordType']
        $hostName = $Config['HostName']
        $domain = $Config['Domain']
        
        $RecordName = "$hostName.$domain"
        
        # Ensure we have both API token and Zone ID
        if ([string]::IsNullOrEmpty($apiToken) -or [string]::IsNullOrEmpty($zoneID)) {
            return $null
        }
        
        # Set up the headers
        $headers = @{
            "Authorization" = "Bearer $apiToken"
            "Content-Type" = "application/json"
        }
        
        # Query Cloudflare API
        $uri = "https://api.cloudflare.com/client/v4/zones/$zoneID/dns_records?type=$recordType&name=$RecordName"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
        
        if ($response.success -and $response.result.Count -gt 0) {
            $record = $response.result[0]
            $recordId = $record.id
            $currentIP = $record.content
            
            Write-CloudflareDDNSLog -Message "Current DNS record: $RecordName points to $currentIP (Record ID: $recordId)" -LogFilePath $script:LogFile
            
            return @{
                ZoneID = $zoneID
                RecordID = $recordId
                CurrentIP = $currentIP
            }
        }
        else {
            Write-CloudflareDDNSLog -Message "ERROR: Failed to retrieve DNS record: $($response.errors | ConvertTo-Json)" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
            return $null
        }
    }
    catch {
        Write-CloudflareDDNSLog -Message "ERROR: Failed to query Cloudflare API $_" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
        return $null
    }
}

function Update-CloudflareDNSRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$UseConsoleLog = $false,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force = $false
    )
    
    # Determine the log target - now always use the script LogFile
    $logTarget = $script:LogFile
    
    try {
        # Start log
        Write-CloudflareDDNSLog -Message "=== Cloudflare DDNS Update Started ===" -LogFilePath $logTarget
        
        # Get the public IP
        $publicIP = Get-PublicIP
        if (!$publicIP) {
            Write-CloudflareDDNSLog -Message "Exiting: Could not determine public IP" -Status "ERROR" -Color "Red" -LogFilePath $logTarget
            return $false
        }
        
        # Get the Cloudflare DNS record
        $record = Get-CloudflareRecord
        if (!$record) {
            Write-CloudflareDDNSLog -Message "Exiting: Could not retrieve Cloudflare record" -Status "ERROR" -Color "Red" -LogFilePath $logTarget
            return $false
        }
        
        # Check if the IP has changed or force update is specified
        if (($record.CurrentIP -ne $publicIP) -or $Force) {
            Write-CloudflareDDNSLog -Message "IP change detected or force update requested: $($record.CurrentIP) -> $publicIP" -LogFilePath $logTarget
            
            # Update the DNS record
            $updateResult = Update-DNSRecord -ZoneID $record.ZoneID -RecordID $record.RecordID -NewIP $publicIP
            
            if ($updateResult) {
                Write-CloudflareDDNSLog -Message "SUCCESS: Updated $RecordName to $publicIP" -Status "SUCCESS" -Color "Green" -LogFilePath $logTarget
                return $true
            }
            else {
                # Update failed
                return $false
            }
        }
        else {
            Write-CloudflareDDNSLog -Message "No IP change detected. Current IP: $publicIP" -LogFilePath $logTarget
            return $true
        }
    }
    catch {
        Write-CloudflareDDNSLog -Message "ERROR: Unexpected error during update: $_" -Status "ERROR" -Color "Red" -LogFilePath $logTarget
        return $false
    }
    finally {
        Write-CloudflareDDNSLog -Message "=== Cloudflare DDNS Update Completed ===" -LogFilePath $logTarget
    }
}

function Show-CloudflareDDNSLog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$LogFilePath = ""
    )
    
    # Use the global log file path if none provided
    if ([string]::IsNullOrEmpty($LogFilePath)) {
        $LogFilePath = $script:LogFile
    }
    
    # Verify log file exists
    if (Test-Path -Path $LogFilePath) {
        Write-Host "Log file found at: $LogFilePath" -ForegroundColor Green
        
        # Display log content with color coding
        Get-Content -Path $LogFilePath | ForEach-Object {
            $line = $_
            Write-Host ($line | Out-String).TrimEnd()
        }
    } else {
        Write-Host "No log file found at: $LogFilePath" -ForegroundColor Yellow
    }
}

function Clear-CloudflareDDNSLog {
    # We now have just one log file to clear
    if (Test-Path -Path $script:LogFile) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        
        # Create backup of the log file
        $backupFile = "$script:LogFile.old"
        try {
            Copy-Item -Path $script:LogFile -Destination $backupFile -Force
            "[{0}] [{1}] Log file cleared. Previous log saved to: {2}" -f $timestamp, $userName, $backupFile | Set-Content -Path $script:LogFile
            Write-Host "Log file cleared and backed up to: $backupFile" -ForegroundColor Green
        } catch {
            Write-Host "Error clearing log file: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Log file does not exist: $script:LogFile" -ForegroundColor Yellow
    }
}

function Show-CloudflareDDNSConfig {
    Write-Host "Current Cloudflare DDNS Configuration:" -ForegroundColor Cyan
    Write-Host "=======================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Zone ID        " -NoNewline -ForegroundColor White
    Write-Host " $($Config['ZoneId'])" -ForegroundColor Yellow
    Write-Host "Domain         " -NoNewline -ForegroundColor White
    Write-Host " $($Config['Domain'])" -ForegroundColor Yellow
    Write-Host "Host           " -NoNewline -ForegroundColor White
    Write-Host " $($Config['HostName'])" -ForegroundColor Yellow
    Write-Host "Full DNS Record" -NoNewline -ForegroundColor White
    Write-Host " $($Config['HostName']).$($Config['Domain'])" -ForegroundColor Green
    Write-Host "TTL            " -NoNewline -ForegroundColor White
    Write-Host " $($Config['TTL']) seconds" -ForegroundColor Yellow
    Write-Host "API Token      " -NoNewline -ForegroundColor White
    $apiTokenPrefix = if ($Config['ApiToken'].Length -ge 5) { $Config['ApiToken'].Substring(0, 5) } else { $Config['ApiToken'] }
    Write-Host " $apiTokenPrefix..." -ForegroundColor Yellow
    Write-Host "Config Storage " -NoNewline -ForegroundColor White
    if ($Config['EncryptionEnabled']) {
        Write-Host "Encrypted" -ForegroundColor Green
    }
    else {
        Write-Host "Plain text (insecure)" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "Log Files:" -ForegroundColor Cyan
    Write-Host "Setup Log File " -NoNewline -ForegroundColor White
    Write-Host " $LogFile" -ForegroundColor Gray
    Write-Host "Task Log File  " -NoNewline -ForegroundColor White
    Write-Host " $TaskLogFile" -ForegroundColor Gray
    Write-Host ""
    
    # Menu for configuration options
    Write-Host "Configuration Options:" -ForegroundColor Cyan
    Write-Host "1: Edit configuration" -ForegroundColor Green
    Write-Host "2: How to create a Cloudflare API token" -ForegroundColor Green
    Write-Host "3: Toggle encryption" -ForegroundColor Green
    Write-Host "4: Export configuration" -ForegroundColor Green
    Write-Host "5: Import configuration" -ForegroundColor Green
    Write-Host "B: Back to main menu" -ForegroundColor Green
    Write-Host ""
    
    $configChoice = Read-Host "Enter your choice (1-5 or B)"
    
    switch ($configChoice.ToUpper()) {
        "1" {
            # Edit the configuration
            Write-Host "`nEditing configuration values:" -ForegroundColor Cyan
            Write-Host "(Press Enter to keep current value)`n" -ForegroundColor Yellow
            
            # Prompt for each value
            $newZoneId = Read-Host "Zone ID [$($Config['ZoneId'])]"
            $newApiToken = Read-Host "API Token [$($Config['ApiToken'].Substring(0, 5))...]"
            $newDomain = Read-Host "Domain [$($Config['Domain'])]"
            $newHostName = Read-Host "Host [$($Config['HostName'])]"
            $newTTL = Read-Host "TTL [$($Config['TTL'])]"
            
            # Ensure the Config is a hashtable
            if ($Config -isnot [hashtable]) {
                $hashConfig = @{}
                if ($Config.PSObject.Properties) {
                    # It's a PSCustomObject
                    foreach ($property in $Config.PSObject.Properties) {
                        $hashConfig[$property.Name] = $property.Value
                    }
                }
                else {
                    # Convert the existing Config to a hashtable
                    foreach ($key in $Config.Keys) {
                        $hashConfig[$key] = $Config[$key]
                    }
                }
                $global:Config = $hashConfig
            }
            
            # Replace empty values with current values
            if (-not [string]::IsNullOrWhiteSpace($newZoneId)) { $global:Config['ZoneId'] = $newZoneId }
            if (-not [string]::IsNullOrWhiteSpace($newApiToken)) { $global:Config['ApiToken'] = $newApiToken }
            if (-not [string]::IsNullOrWhiteSpace($newDomain)) { $global:Config['Domain'] = $newDomain }
            if (-not [string]::IsNullOrWhiteSpace($newHostName)) { $global:Config['HostName'] = $newHostName }
            if (-not [string]::IsNullOrWhiteSpace($newTTL)) { $global:Config['TTL'] = [int]$newTTL }
            
            # Save the configuration
            $configPath = Join-Path -Path $Config.ConfigDir -ChildPath $ConfigFileName
            
            try {
                # Always update the JSON config for compatibility
                $configToExport = @{}
                foreach ($key in $global:Config.Keys) {
                    if ($key -eq "ApiToken" -and $global:Config["EncryptionEnabled"]) {
                        $configToExport[$key] = "ENCRYPTED - SEE SECURE CONFIG FILE"
                    }
                    else {
                        $configToExport[$key] = $global:Config[$key]
                    }
                }
                
                $configToExport | ConvertTo-Json | Set-Content -Path $configPath -Force
                
                # If encryption is enabled, also update secure config
                if ($global:Config["EncryptionEnabled"]) {
                    Export-CloudflareDDNSSecureConfig -Config $global:Config
                }
                
                Write-Host "`nConfiguration has been updated successfully!" -ForegroundColor Green
                Write-CloudflareDDNSLog -Message "Configuration updated via editor" -Status "INFO" -Color "Green"
            }
            catch {
                Write-Host "`nError updating configuration: $_" -ForegroundColor Red
                Write-CloudflareDDNSLog -Message "Error updating configuration: $_" -Status "ERROR" -Color "Red"
            }
        }
        "2" {
            # Display information about creating a Cloudflare API token
            Clear-Host
            Write-Host "How to Create a Cloudflare API Token" -ForegroundColor Cyan
            Write-Host "====================================" -ForegroundColor Cyan
            Write-Host ""
            Write-Host "1. Log in to your Cloudflare dashboard at https://dash.cloudflare.com" -ForegroundColor White
            Write-Host "2. Go to 'My Profile' > 'API Tokens' > 'Create Token'" -ForegroundColor White
            Write-Host "3. Select 'Create Custom Token'" -ForegroundColor White
            Write-Host "4. Name it 'DDNS Updater'" -ForegroundColor White
            Write-Host "5. Under 'Permissions':" -ForegroundColor White
            Write-Host "   - Zone - DNS - Edit" -ForegroundColor Yellow
            Write-Host "   - Zone - Zone - Read" -ForegroundColor Yellow
            Write-Host "6. Under 'Zone Resources':" -ForegroundColor White
            Write-Host "   - Include - Specific zone - your domain (e.g., $($Config['Domain']))" -ForegroundColor Yellow
            Write-Host "7. IMPORTANT: Set 'TTL' to 'No expiration' or your token will expire and break DDNS" -ForegroundColor Red
            Write-Host "8. Click 'Continue to summary' then 'Create Token'" -ForegroundColor White
            Write-Host "9. Copy the generated token (you'll only see it once)" -ForegroundColor White
            Write-Host ""
            Write-Host "How to Find Your Zone ID:" -ForegroundColor Cyan
            Write-Host "=========================" -ForegroundColor Cyan
            Write-Host "1. Go to your Cloudflare dashboard" -ForegroundColor White
            Write-Host "2. Select your domain" -ForegroundColor White
            Write-Host "3. On the Overview page, scroll down to the API section" -ForegroundColor White
            Write-Host "4. Your Zone ID is listed there (a 32-character alphanumeric string)" -ForegroundColor White
            Write-Host ""
            
            $openDashboard = Read-Host "Would you like to open Cloudflare dashboard in your browser? (Y/N)"
            if ($openDashboard.ToUpper() -eq "Y") {
                Start-Process "https://dash.cloudflare.com"
                Write-Host "Browser opened to Cloudflare dashboard. Create your token and then return here." -ForegroundColor Yellow
                Write-Host "Press Enter when you're ready to continue..." -ForegroundColor Cyan
                Read-Host
            }
        }
        "3" {
            # Toggle encryption
            $Config['EncryptionEnabled'] = -not $Config['EncryptionEnabled']
            
            if ($Config['EncryptionEnabled']) {
                Write-Host "Encryption has been enabled for sensitive configuration data." -ForegroundColor Green
                
                # Create secure config file
                if (Export-CloudflareDDNSSecureConfig -Config $Config) {
                    Write-Host "Secure configuration file created successfully." -ForegroundColor Green
                }
                else {
                    Write-Host "Failed to create secure configuration file." -ForegroundColor Red
                    $Config['EncryptionEnabled'] = $false
                }
            }
            else {
                Write-Host "WARNING: Encryption has been disabled. API tokens will be stored in plain text." -ForegroundColor Red
                Write-Host "This is not recommended for production environments." -ForegroundColor Red
                
                # Confirm disabling encryption
                $confirm = Read-Host "Are you sure you want to disable encryption? (Y/N)"
                if ($confirm.ToUpper() -ne "Y") {
                    $Config['EncryptionEnabled'] = $true
                    Write-Host "Encryption remains enabled." -ForegroundColor Green
                }
                else {
                    # Remove secure config file
                    $encryptedConfigPath = Join-Path -Path $Config.ConfigDir -ChildPath $EncryptedConfigFileName
                    if (Test-Path $encryptedConfigPath) {
                        Remove-Item -Path $encryptedConfigPath -Force
                    }
                    
                    # Update regular config with actual values
                    $configPath = Join-Path -Path $Config.ConfigDir -ChildPath $ConfigFileName
                    $Config | ConvertTo-Json | Set-Content -Path $configPath -Force
                    
                    Write-Host "Encryption has been disabled. Secure configuration file removed." -ForegroundColor Yellow
                }
            }
            
            # Log encryption change
            Write-CloudflareDDNSLog -Message "Configuration encryption setting changed to: $($Config['EncryptionEnabled'])" -Status "INFO" -Color "Yellow"
        }
        "4" {
            # Export configuration to a user-selected location
            $exportPath = Read-Host "Enter path to export configuration (or press Enter for Desktop)"
            
            if ([string]::IsNullOrWhiteSpace($exportPath)) {
                $exportPath = [Environment]::GetFolderPath("Desktop")
            }
            
            if (-not (Test-Path $exportPath -PathType Container)) {
                Write-Host "Invalid export path. Export cancelled." -ForegroundColor Red
            }
            else {
                $exportFilePath = Join-Path -Path $exportPath -ChildPath "CloudflareDDNS-ExportedConfig.json"
                try {
                    # Export a clean version of the config (remove secure data)
                    $exportConfig = @{}
                    foreach ($key in $Config.Keys) {
                        if ($key -eq "ApiToken") {
                            $exportConfig[$key] = "API_TOKEN_PLACEHOLDER"
                        }
                        else {
                            $exportConfig[$key] = $Config[$key]
                        }
                    }
                    
                    $exportConfig | ConvertTo-Json | Set-Content -Path $exportFilePath -Force
                    Write-Host "Configuration exported to: $exportFilePath" -ForegroundColor Green
                    Write-Host "NOTE: API Token was not exported for security reasons." -ForegroundColor Yellow
                    Write-CloudflareDDNSLog -Message "Configuration exported to: $exportFilePath" -Status "INFO" -Color "Green"
                }
                catch {
                    Write-Host "Error exporting configuration: $_" -ForegroundColor Red
                    Write-CloudflareDDNSLog -Message "Error exporting configuration: $_" -Status "ERROR" -Color "Red"
                }
            }
        }
        "5" {
            # Import configuration from a user-selected location
            $importPath = Read-Host "Enter path to JSON configuration file to import"
            
            if ([string]::IsNullOrWhiteSpace($importPath) -or (-not (Test-Path $importPath -PathType Leaf))) {
                Write-Host "Invalid import file path. Import cancelled." -ForegroundColor Red
            }
            else {
                try {
                    $importedConfig = Get-Content -Path $importPath -Raw | ConvertFrom-Json
                    
                    # Convert to hashtable
                    $importedConfigHashtable = @{}
                    foreach ($property in $importedConfig.PSObject.Properties) {
                        $importedConfigHashtable[$property.Name] = $property.Value
                    }
                    
                    # Preserve API Token if importing config doesn't have one
                    if (-not $importedConfigHashtable.ApiToken -or $importedConfigHashtable.ApiToken -eq "API_TOKEN_PLACEHOLDER") {
                        $importedConfigHashtable.ApiToken = $Config['ApiToken']
                    }
                    
                    # Update current config
                    foreach ($key in $importedConfigHashtable.Keys) {
                        $Config[$key] = $importedConfigHashtable[$key]
                    }
                    
                    # Save updated config
                    $configPath = Join-Path -Path $Config.ConfigDir -ChildPath $ConfigFileName
                    
                    # Always update the JSON config for compatibility
                    $configToExport = @{}
                    foreach ($key in $Config.Keys) {
                        if ($key -eq "ApiToken" -and $Config['EncryptionEnabled']) {
                            $configToExport[$key] = "ENCRYPTED - SEE SECURE CONFIG FILE"
                        }
                        else {
                            $configToExport[$key] = $Config[$key]
                        }
                    }
                    
                    $configToExport | ConvertTo-Json | Set-Content -Path $configPath -Force
                    
                    # If encryption is enabled, also update secure config
                    if ($Config['EncryptionEnabled']) {
                        Export-CloudflareDDNSSecureConfig -Config $Config
                    }
                    
                    Write-Host "Configuration imported successfully!" -ForegroundColor Green
                    Write-CloudflareDDNSLog -Message "Configuration imported from: $importPath" -Status "INFO" -Color "Green"
                }
                catch {
                    Write-Host "Error importing configuration: $_" -ForegroundColor Red
                    Write-CloudflareDDNSLog -Message "Error importing configuration: $_" -Status "ERROR" -Color "Red"
                }
            }
        }
        "B" {
            # Return to main menu
            return
        }
        default {
            Write-Host "Invalid selection." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
    }
    
    Write-Host ""
    Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
    Read-Host
}

function Install-CloudflareDDNSTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$UseVBScript = $false,
        
        [Parameter(Mandatory = $false)]
        [string]$CustomInterval = ""
    )
    
    Write-CloudflareDDNSLog -Message "Installing scheduled task with script path: $scriptPath" -Status "INFO" -Color "White"
    
    # Determine script path
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrEmpty($scriptPath)) {
        $scriptPath = $PSCommandPath
    }
    
    # Convert to absolute path if needed
    if (-not [System.IO.Path]::IsPathRooted($scriptPath)) {
        $scriptPath = Join-Path -Path $PSScriptRoot -ChildPath $scriptPath
    }
    
    $taskName = "CloudflareDDNS"
    
    # Create arguments for silent execution
    $programDataLogDir = "$env:ProgramData\CloudflareDDNS\logs"
    if (!(Test-Path -Path $programDataLogDir)) {
        New-Item -Path $programDataLogDir -ItemType Directory -Force | Out-Null
    }
    
    # Use the main log file
    $actionArgs = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$scriptPath`" -Silent -ForceDirect -LogFile `"$script:LogFile`""
    
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
      <Command>$actionPath</Command>
      <Arguments>$actionArgs</Arguments>
    </Exec>
  </Actions>
</Task>
"@
        
        # Register the task using the XML definition
        Register-ScheduledTask -TaskName $taskName -Xml $taskXml -Force | Out-Null
        
        $visibilityText = if ($invisible) { "invisibly (no console window)" } else { "visibly (with console window)" }
        Write-CloudflareDDNSLog -Message "Successfully installed scheduled task '$taskName'" -Status "SUCCESS" -Color "Green"
        Write-Host "Scheduled task '$taskName' has been created successfully." -ForegroundColor Green
        Write-Host ""
        Write-Host "The task will run $visibilityText with the following triggers:" -ForegroundColor White
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

function CreateVBScript {
    param (
        [string]$scriptPath
    )
    
    $vbsContent = @"
' CloudflareDDNSInvisible.vbs
' This script launches PowerShell completely hidden without showing any window
' Created to solve the issue of visible windows when using -WindowStyle Hidden

Option Explicit

' Create debug log function
Sub WriteLog(strMessage)
    Dim objFSO, objLogFile
    Dim strLogPath, strLogEntry
    
    strLogPath = "C:\Windows\TEMP\CloudflareDDNS.vbs.log"
    strLogEntry = Now() & " - " & strMessage
    
    On Error Resume Next
    Set objFSO = CreateObject("Scripting.FileSystemObject")
    Set objLogFile = objFSO.OpenTextFile(strLogPath, 8, True)
    objLogFile.WriteLine strLogEntry
    objLogFile.Close
    On Error Goto 0
End Sub

' Log script start
WriteLog "VBS wrapper starting for CloudflareDDNS updater"

' Define the path to PowerShell and the script
Dim PowerShellPath, ScriptPath, Arguments
PowerShellPath = "powershell.exe"
ScriptPath = "$scriptPath"
Arguments = "-NoProfile -ExecutionPolicy Bypass -File """ & ScriptPath & """ -Silent -ShowWindow"

' Log command
WriteLog "Command: " & PowerShellPath & " " & Arguments

' Create a shell object
Dim objShell
Set objShell = CreateObject("WScript.Shell")

' Run PowerShell with 0 window style (hidden)
' 0 = Hidden window
' True = don't wait for program to finish
WriteLog "Executing PowerShell command..."
objShell.Run PowerShellPath & " " & Arguments, 0, False
WriteLog "PowerShell command executed"

' Also create a direct PowerShell log for debugging as backup
On Error Resume Next
objShell.Run "powershell.exe -Command ""& { Add-Content -Path 'C:\Windows\TEMP\CloudflareDDNS.powershell.log' -Value '$(Get-Date) - VBS triggered PowerShell execution' }""", 0, True
On Error Goto 0

' Clean up
Set objShell = Nothing
WriteLog "VBS wrapper completed"
"@

    $vbsPath = Join-Path -Path (Split-Path -Parent $scriptPath) -ChildPath "CloudflareDDNSInvisible.vbs"
    $vbsContent | Out-File -FilePath $vbsPath -Encoding ASCII -Force
    
    # Also write a direct log for debugging
    try {
        $debugLogPath = "C:\Windows\TEMP\CloudflareDDNS.debug.log"
        "$(Get-Date) - Created VBScript wrapper at $vbsPath" | Out-File -FilePath $debugLogPath -Append
    } catch {}
    
    Write-CloudflareDDNSLog -Message "Created VBScript wrapper at $vbsPath" -Status "INFO" -Color "Green"
    return $vbsPath
}

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

function Start-CloudflareDDNSTask {
    $taskName = "CloudflareDDNSUpdater"
    
    try {
        # Check if task exists
        $taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        
        if ($taskExists) {
            Write-Host "Starting scheduled task '$taskName'..." -ForegroundColor Yellow
            $result = Start-ScheduledTask -TaskName $taskName
            
            # Add a slight delay to check task status
            Start-Sleep -Seconds 1
            
            # Get updated task info
            $task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
            
            if ($task.State -eq "Running") {
                Write-Host "Task is now running!" -ForegroundColor Green
                Write-CloudflareDDNSLog -Message "Manually triggered scheduled task '$taskName'" -Status "INFO" -Color "Green"
            }
            else {
                Write-Host "Task could not be started. Current state: $($task.State)" -ForegroundColor Yellow
                Write-CloudflareDDNSLog -Message "Manually triggered scheduled task '$taskName' but status is '$($task.State)'" -Status "INFO" -Color "Yellow"
                
                # Perform a direct update instead
                Write-Host "Performing direct update instead..." -ForegroundColor Yellow
                Update-CloudflareDNSRecord -UseConsoleLog -Force
            }
            
            Write-Host ""
            Write-Host "Note: Task runs in the background. Check log files for results." -ForegroundColor Cyan
        }
        else {
            Write-Host "Scheduled task '$taskName' was not found." -ForegroundColor Red
            Write-Host "Please install the task first using menu option 2." -ForegroundColor Yellow
            Write-CloudflareDDNSLog -Message "Failed to trigger task '$taskName' - task not found" -Status "ERROR" -Color "Red"
        }
    }
    catch {
        Write-CloudflareDDNSLog -Message "Failed to start scheduled task: $_" -Status "ERROR" -Color "Red"
        Write-Host "Error starting scheduled task: $_" -ForegroundColor Red
        
        # Try direct update on error
        Write-Host "Attempting direct update instead..." -ForegroundColor Yellow
        Update-CloudflareDNSRecord -UseConsoleLog -Force
    }
}

function Test-CloudflareAPIConnection {
    Write-Host "Testing Cloudflare API connection..." -ForegroundColor Yellow
    Write-CloudflareDDNSLog -Message "Testing Cloudflare API connection" -Status "INFO" -Color "Yellow"
    
    try {
        $headers = @{
            "Authorization" = "Bearer $($Config['ApiToken'])"
            "Content-Type"  = "application/json"
        }
        
        # Test Zone endpoint
        Write-Host "Testing Zone access..." -ForegroundColor White
        $zoneUri = "https://api.cloudflare.com/client/v4/zones/$($Config['ZoneId'])"
        $zoneResponse = Invoke-RestMethod -Uri $zoneUri -Headers $headers -Method Get -ErrorAction Stop
        
        if ($zoneResponse.success) {
            $zoneName = $zoneResponse.result.name
            Write-Host "Successfully accessed zone: $zoneName" -ForegroundColor Green
            Write-CloudflareDDNSLog -Message "Successfully accessed zone: $zoneName" -Status "SUCCESS" -Color "Green"
        }
        else {
            Write-Host "Zone access FAILED: $($zoneResponse.errors | ConvertTo-Json -Compress)" -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "Zone access failed: $($zoneResponse.errors | ConvertTo-Json -Compress)" -Status "ERROR" -Color "Red"
            return $false
        }
        
        # Test DNS Records endpoint
        Write-Host "Testing DNS Records access..." -ForegroundColor White
        $RecordName = "$($Config['HostName']).$($Config['Domain'])"
        $dnsUri = "https://api.cloudflare.com/client/v4/zones/$($Config['ZoneId'])/dns_records?type=A&name=$RecordName"
        $dnsResponse = Invoke-RestMethod -Uri $dnsUri -Headers $headers -Method Get -ErrorAction Stop
        
        if ($dnsResponse.success) {
            if ($dnsResponse.result.Count -gt 0) {
                $recordIP = $dnsResponse.result[0].content
                $recordId = $dnsResponse.result[0].id
                Write-Host "Successfully accessed DNS record: $RecordName -> $recordIP (ID: $recordId)" -ForegroundColor Green
                Write-CloudflareDDNSLog -Message "Successfully accessed DNS record: $RecordName -> $recordIP" -Status "SUCCESS" -Color "Green"
            }
            else {
                Write-Host "WARNING: DNS record $RecordName not found. It may need to be created." -ForegroundColor Yellow
                Write-CloudflareDDNSLog -Message "DNS record $RecordName not found" -Status "WARNING" -Color "Yellow"
            }
        }
        else {
            Write-Host "DNS Records access FAILED: $($dnsResponse.errors | ConvertTo-Json -Compress)" -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "DNS Records access failed: $($dnsResponse.errors | ConvertTo-Json -Compress)" -Status "ERROR" -Color "Red"
            return $false
        }
        
        Write-Host "`nAPI Connection Test SUCCESSFUL!" -ForegroundColor Green
        Write-Host "Your Cloudflare API credentials are working correctly." -ForegroundColor Green
        Write-CloudflareDDNSLog -Message "API Connection Test SUCCESSFUL" -Status "SUCCESS" -Color "Green"
        return $true
    }
    catch {
        Write-Host "`nAPI Connection Test FAILED: $_" -ForegroundColor Red
        Write-Host "Please check your API Token and Zone ID." -ForegroundColor Red
        
        if ($_.Exception.Response.StatusCode.value__ -eq 401) {
            Write-Host "Error 401: Unauthorized - Your API token is invalid or expired." -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "API Connection Test FAILED: 401 Unauthorized - Invalid token" -Status "ERROR" -Color "Red"
        }
        elseif ($_.Exception.Response.StatusCode.value__ -eq 403) {
            Write-Host "Error 403: Forbidden - Your API token doesn't have sufficient permissions." -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "API Connection Test FAILED: 403 Forbidden - Insufficient permissions" -Status "ERROR" -Color "Red"
        }
        elseif ($_.Exception.Response.StatusCode.value__ -eq 404) {
            Write-Host "Error 404: Not Found - Check your Zone ID." -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "API Connection Test FAILED: 404 Not Found - Invalid Zone ID" -Status "ERROR" -Color "Red"
        }
        else {
            Write-CloudflareDDNSLog -Message "API Connection Test FAILED: $_" -Status "ERROR" -Color "Red"
        }
        
        return $false
    }
}

function Show-CloudflareDDNSStatus {
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
    
    $RecordName = "$($Config['HostName']).$($Config['Domain'])"
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
    $taskName = "CloudflareDDNSUpdater"
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

# New function to configure API token
function Configure-CloudflareAPIToken {
    param (
        [string]$ApiToken = "",
        [string]$ZoneId = "",
        [string]$Domain = "",
        [string]$HostName = "",
        [switch]$AsSystem
    )
    
    # If not running as SYSTEM and encryption is enabled, try to elevate
    if ($Config['EncryptionEnabled'] -and -not (Test-RunningAsSystem) -and -not $AsSystem) {
        $params = @{}
        if ($ApiToken) { $params['ApiToken'] = $ApiToken }
        if ($ZoneId) { $params['ZoneId'] = $ZoneId }
        if ($Domain) { $params['Domain'] = $Domain }
        if ($HostName) { $params['HostName'] = $HostName }
        
        return Invoke-ConfigOperationAsSystem -Operation "Configure" -Parameters $params
    }
    
    # Regular configuration logic
    Write-Host ""
    Write-Host "===== Cloudflare API Token Configuration =====" -ForegroundColor Cyan
    
    # If running with parameters (likely from SYSTEM elevation), use those directly
    if ($AsSystem -and $ApiToken) {
        $Config["ApiToken"] = $ApiToken
        $global:ConfigNeedsToken = $false
        
        if ($ZoneId) {
            $Config["ZoneId"] = $ZoneId
        }
        
        if ($Domain) {
            $Config["Domain"] = $Domain
        }
        
        if ($HostName) {
            $Config["HostName"] = $HostName
        }
        
        # Save the updated config
        try {
            $configPath = Join-Path -Path $Config.ConfigDir -ChildPath $ConfigFileName
            
            if ($Config["EncryptionEnabled"]) {
                Export-CloudflareDDNSSecureConfig -Config $Config
                return $true
            }
            else {
                # Save to regular config
                $Config | ConvertTo-Json | Set-Content -Path $configPath -Force
                return $true
            }
        }
        catch {
            Write-Error "Error saving API Token configuration: $_"
            return $false
        }
    }
    
    # Interactive configuration
    Write-Host ""
    Write-Host "You will need a Cloudflare API Token with:" -ForegroundColor White
    Write-Host "- Zone:DNS:Edit permission" -ForegroundColor Yellow
    Write-Host "- Zone:Zone:Read permission" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Would you like to see instructions for creating a token?" -ForegroundColor White
    $showInstructions = Read-Host "Enter 'Y' for instructions or any other key to continue (Y/N)"
    
    if ($showInstructions.ToUpper() -eq 'Y') {
        Clear-Host
        Write-Host "How to Create a Cloudflare API Token" -ForegroundColor Cyan
        Write-Host "====================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Log in to your Cloudflare dashboard at https://dash.cloudflare.com" -ForegroundColor White
        Write-Host "2. Go to 'My Profile' > 'API Tokens' > 'Create Token'" -ForegroundColor White
        Write-Host "3. Select 'Create Custom Token'" -ForegroundColor White
        Write-Host "4. Name it 'DDNS Updater'" -ForegroundColor White
        Write-Host "5. Under 'Permissions':" -ForegroundColor White
        Write-Host "   - Zone - DNS - Edit" -ForegroundColor Yellow
        Write-Host "   - Zone - Zone - Read" -ForegroundColor Yellow
        Write-Host "6. Under 'Zone Resources':" -ForegroundColor White
        Write-Host "   - Include - Specific zone - your domain (e.g., $($Config['Domain']))" -ForegroundColor Yellow
        Write-Host "7. IMPORTANT: Set 'TTL' to 'No expiration' or your token will expire and break DDNS" -ForegroundColor Red
        Write-Host "8. Click 'Continue to summary' then 'Create Token'" -ForegroundColor White
        Write-Host "9. Copy the generated token (you'll only see it once)" -ForegroundColor White
        Write-Host ""
        Write-Host "How to Find Your Zone ID:" -ForegroundColor Cyan
        Write-Host "=========================" -ForegroundColor Cyan
        Write-Host "1. Go to your Cloudflare dashboard" -ForegroundColor White
        Write-Host "2. Select your domain" -ForegroundColor White
        Write-Host "3. On the Overview page, scroll down to the API section" -ForegroundColor White
        Write-Host "4. Your Zone ID is listed there (a 32-character alphanumeric string)" -ForegroundColor White
        Write-Host ""
        
        $openDashboard = Read-Host "Would you like to open Cloudflare dashboard in your browser? (Y/N)"
        if ($openDashboard.ToUpper() -eq "Y") {
            Start-Process "https://dash.cloudflare.com"
            Write-Host "Browser opened to Cloudflare dashboard. Create your token and then return here." -ForegroundColor Yellow
            Write-Host "Press Enter when you're ready to continue..." -ForegroundColor Cyan
            Read-Host
        }
    }
    
    Write-Host ""
    Write-Host "Please enter your Cloudflare API Token:" -ForegroundColor Yellow
    $newApiToken = Read-Host -AsSecureString "API Token"
    
    if ($newApiToken.Length -gt 0) {
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($newApiToken)
        $Config["ApiToken"] = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        $global:ConfigNeedsToken = $false
        
        # Now prompt for Zone ID
        Write-Host ""
        Write-Host "Please enter your Cloudflare Zone ID:" -ForegroundColor Yellow
        if ($Config["ZoneId"] -eq "YOUR_ZONE_ID") {
            Write-Host "(This is a 32-character ID found in your Cloudflare dashboard)" -ForegroundColor Cyan
        }
        else {
            Write-Host "Current Zone ID is: $($Config["ZoneId"])" -ForegroundColor Cyan
            Write-Host "Press Enter to keep current value or enter a new Zone ID" -ForegroundColor Cyan
        }
        
        $newZoneId = Read-Host "Zone ID"
        
        if (-not [string]::IsNullOrWhiteSpace($newZoneId)) {
            $Config["ZoneId"] = $newZoneId
        }
        
        # Prompt for domain info if it's still the default
        if ($Config["Domain"] -eq "yourdomain.com") {
            Write-Host ""
            Write-Host "Please enter your domain name:" -ForegroundColor Yellow
            $newDomain = Read-Host "Domain (e.g. example.com)"
            
            if (-not [string]::IsNullOrWhiteSpace($newDomain)) {
                $Config["Domain"] = $newDomain
            }
            
            Write-Host ""
            Write-Host "Please enter the hostname for the DNS record:" -ForegroundColor Yellow
            Write-Host "(Use '@' for the root domain, or a subdomain like 'www')" -ForegroundColor Cyan
            $newHostname = Read-Host "Hostname"
            
            if (-not [string]::IsNullOrWhiteSpace($newHostname)) {
                $Config["HostName"] = $newHostname
            }
        }
        
        # Save the updated config
        try {
            $configPath = Join-Path -Path $Config.ConfigDir -ChildPath $ConfigFileName
            
            if ($Config["EncryptionEnabled"]) {
                Export-CloudflareDDNSSecureConfig -Config $Config
                Write-Host "Saved new API token to secure configuration." -ForegroundColor Green
            }
            else {
                # Save to regular config
                $Config | ConvertTo-Json | Set-Content -Path $configPath -Force
                Write-Host "Saved new API token to configuration." -ForegroundColor Green
            }
            
            Write-CloudflareDDNSLog -Message "API Token configured successfully" -Status "SUCCESS" -Color "Green"
            
            # Test the API connection
            Write-Host ""
            Write-Host "Would you like to test the API connection now?" -ForegroundColor Yellow
            $testAPI = Read-Host "Enter 'Y' to test or any other key to skip (Y/N)"
            
            if ($testAPI.ToUpper() -eq 'Y') {
                Test-CloudflareAPIConnection
            }
            
            return $true
        }
        catch {
            Write-Host "Error saving configuration: $_" -ForegroundColor Red
            Write-CloudflareDDNSLog -Message "Error saving API Token configuration: $_" -Status "ERROR" -Color "Red"
            return $false
        }
    }
    else {
        Write-Host "No API token provided. Configuration not updated." -ForegroundColor Red
        return $false
    }
    
    Write-Host ""
    Write-Host "Press Enter to return to the menu..." -ForegroundColor Cyan
    Read-Host
    return $true
}

# Ensure log files and paths are properly initialized for SYSTEM context
function Initialize-LogEnvironment {
    param (
        [Parameter(Mandatory = $false)]
        [string]$ConfigDir = "",
        [Parameter(Mandatory = $false)]
        [string]$LogDir = "",
        [Parameter(Mandatory = $false)]
        [string]$ExplicitLogFile = ""
    )
    
    # Always use a standard, centralized log location - hardcoded to ProgramData
    $mainLogDir = "$env:ProgramData\CloudflareDDNS\logs"
    
    # Ensure directory exists
    if (-not (Test-Path -Path $mainLogDir)) {
        try {
            New-Item -Path $mainLogDir -ItemType Directory -Force | Out-Null
        } catch {
            # If creation fails, simply report the error but continue
            Write-Error "Failed to create log directory: $mainLogDir - $($_.Exception.Message)"
        }
    }
    
    # Set the single log file path
    $script:LogFile = "$mainLogDir\CloudflareDDNS.log"
    
    # Override with explicit log file if provided
    if (-not [string]::IsNullOrEmpty($ExplicitLogFile)) {
        $script:LogFile = $ExplicitLogFile
        
        # Ensure the directory exists for the explicit log file
        $logFileDir = Split-Path -Path $ExplicitLogFile -Parent
        if (-not (Test-Path -Path $logFileDir)) {
            try {
                New-Item -Path $logFileDir -ItemType Directory -Force | Out-Null
            } catch {
                Write-Error "Failed to create log directory: $logFileDir - $($_.Exception.Message)" 
            }
        }
    }
    
    # Write initial log entry if the log doesn't exist
    if (-not (Test-Path -Path $script:LogFile)) {
        try {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            "[$timestamp] [$user] [INIT] Log file initialized" | Out-File -FilePath $script:LogFile -Append
        } catch {
            Write-Error "Failed to initialize log file: $script:LogFile - $($_.Exception.Message)"
        }
    }
    
    # Return a simplified structure with just the main log file
    return @{
        ConfigDir = $ConfigDir
        LogDir = $mainLogDir
        LogFile = $script:LogFile
    }
}

# Main execution starts here
# Initialize the configuration first - using NoPrompt to prevent immediate API token requests
$script:Config = Initialize-CloudflareDDNSConfig -NoPrompt

# Initialize log file paths
$script:LogFile = Join-Path -Path $Config.LogDir -ChildPath "CloudflareDDNS.log"
$script:TaskLogFile = Join-Path -Path $Config.LogDir -ChildPath "CloudflareDDNS-Task.log"

# Ensure log directory exists
if (-not (Test-Path -Path $Config.LogDir)) {
    New-Item -ItemType Directory -Path $Config.LogDir -Force | Out-Null
}

# Initialize main variables
$script:ConfigFileName = "CloudflareDDNS-Config.json"
$script:SecureConfigFileName = "CloudflareDDNS-SecureConfig.json"
$script:ConfigDir = Join-Path -Path $PSScriptRoot -ChildPath "config"
$script:LogDir = Join-Path -Path $ConfigDir -ChildPath "logs"

# Set up log file paths
$Config = Initialize-CloudflareDDNSConfig -NoPrompt:$Silent
$ConfigDir = $Config.ConfigDir
$LogDir = $Config.LogDir

# Initialize log environment, including the LogFile parameter if specified
if ($PSBoundParameters.ContainsKey('LogFile') -and (-not [string]::IsNullOrEmpty($LogFile))) {
    $logEnv = Initialize-LogEnvironment -ConfigDir $ConfigDir -ExplicitLogFile $LogFile
} else {
    $logEnv = Initialize-LogEnvironment -ConfigDir $ConfigDir
}

# Set up global log path - just one consolidated location
$script:LogFile = $logEnv.LogFile

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

if ($Silent) {
    # Initialize early debug logs - first priority
    $runContext = if (Test-RunningAsSystem) { "SYSTEM" } else { "USER" }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    
    # Create additional log for direct task execution
    if ($ForceDirect) {
        try {
            # Set task system log path that will definitely work
            "$timestamp [$user] Task direct execution starting" | Out-File -FilePath $script:LogFile -Append
        } catch {
            # If we can't log, at least try to display an error
            Write-Error "Failed to write startup log: $($_.Exception.Message)"
        }
    }
    
    # Run the update in silent mode for scheduled tasks or command-line runs
    $updateResult = Update-CloudflareDNSRecord
    
    # Keep the window open if requested
    if ($ShowWindow) {
        Write-Host "`nPress Enter to close this window..." -ForegroundColor Cyan
        Read-Host
    }
    
    exit
}
else {
    # Interactive mode - show menu
    $continue = $true
    while ($continue) {
        $continue = Show-CloudflareDDNSMenu
    }
} 

function Update-DNSRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZoneID,
        
        [Parameter(Mandatory = $true)]
        [string]$RecordID,
        
        [Parameter(Mandatory = $true)]
        [string]$NewIP
    )
    
    try {
        # Load configuration
        $apiToken = $Config['APIToken']
        $recordType = $Config['RecordType']
        $hostName = $Config['HostName']
        $domain = $Config['Domain']
        $ttl = $Config['TTL']
        $proxied = $Config['Proxied']
        
        $RecordName = "$hostName.$domain"
        
        # Set up the headers
        $headers = @{
            "Authorization" = "Bearer $apiToken"
            "Content-Type" = "application/json"
        }
        
        # Create the request body
        $body = @{
            type = $recordType
            name = $RecordName
            content = $NewIP
            ttl = $ttl
            proxied = $proxied
        } | ConvertTo-Json
        
        # Update the DNS record
        $uri = "https://api.cloudflare.com/client/v4/zones/$ZoneID/dns_records/$RecordID"
        $response = Invoke-RestMethod -Uri $uri -Headers $headers -Method Put -Body $body
        
        if ($response.success) {
            return $true
        }
        else {
            Write-CloudflareDDNSLog -Message "ERROR: Failed to update DNS record: $($response.errors | ConvertTo-Json)" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
            return $false
        }
    }
    catch {
        Write-CloudflareDDNSLog -Message "ERROR: Failed to update Cloudflare record: $_" -Status "ERROR" -Color "Red" -LogFilePath $script:LogFile
        return $false
    }
} 

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