# CloudflareDDNS.psm1
# Main module file for CloudflareDDNS module

# Create variable to store the module path
$script:ModuleRoot = $PSScriptRoot
$script:ConfigPath = Join-Path -Path $script:ModuleRoot -ChildPath "Config"
$script:PublicPath = Join-Path -Path $script:ModuleRoot -ChildPath "Public"
$script:PrivatePath = Join-Path -Path $script:ModuleRoot -ChildPath "Private"

# Default configuration - will be overridden by external config file if it exists
$script:defaultConfig = @{
    ZoneId            = "your-zone-id"
    ApiToken          = "your-api-token"
    Domain            = "yourdomain.com"
    HostName          = "subdomain"
    TTL               = 120
    LogDir            = "$env:ProgramData\CloudflareDDNS"
    ConfigDir         = "$env:ProgramData\CloudflareDDNS"
    EncryptionEnabled = $true
    RecordType        = "A"
    Proxied           = $false
}

# Global variables for configuration
$script:ConfigFileName = "CloudflareDDNS-Config.json"
$script:EncryptedConfigFileName = "CloudflareDDNS-Config.secure"
$script:Config = $null
$script:LogFile = $null
$script:TaskLogFile = $null
$script:ConfigNeedsToken = $false

# Import all private function files
$privateFiles = Get-ChildItem -Path $script:PrivatePath -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $privateFiles) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "Failed to import private function file $($file.FullName): $_"
    }
}

# Import all public function files
$publicFiles = Get-ChildItem -Path $script:PublicPath -Filter "*.ps1" -ErrorAction SilentlyContinue
foreach ($file in $publicFiles) {
    try {
        . $file.FullName
    }
    catch {
        Write-Error "Failed to import public function file $($file.FullName): $_"
    }
}

# Initialize module
function Initialize-Module {
    # Initialize configuration
    $script:Config = Initialize-CloudflareDDNSConfig -NoPrompt

    # Initialize log file paths
    $script:LogFile = Join-Path -Path $Config.LogDir -ChildPath "CloudflareDDNS.log"
    $script:TaskLogFile = Join-Path -Path $Config.LogDir -ChildPath "CloudflareDDNS-Task.log"

    # Ensure log directory exists
    if (-not (Test-Path -Path $Config.LogDir)) {
        New-Item -ItemType Directory -Path $Config.LogDir -Force | Out-Null
    }
}

# Run initialization when module is imported
Initialize-Module

# Export the public functions
Export-ModuleMember -Function $publicFiles.BaseName 