function Initialize-CloudflareDDNSConfig {
    [CmdletBinding()]
    param(
        [switch]$NoPrompt
    )
    
    # Initialize the global variable
    $script:ConfigNeedsToken = $false
    
    # Load Config Directory
    $configDir = Join-Path -Path $script:ModuleRoot -ChildPath "Config"
    if (-not (Test-Path -Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }
    
    # Filenames
    $configPath = Join-Path -Path $configDir -ChildPath $script:ConfigFileName
    $secureConfigPath = Join-Path -Path $configDir -ChildPath $script:EncryptedConfigFileName
    
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
        RecordType        = "A"
        Proxied           = $false
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
            if ($secureConfig.RecordType) {
                $config["RecordType"] = $secureConfig.RecordType
            }
            if ($null -ne $secureConfig.Proxied) {
                $config["Proxied"] = $secureConfig.Proxied
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
    if ($config["ApiToken"] -eq "ENCRYPTED - SEE SECURE CONFIG FILE" -or 
        $config["ApiToken"] -eq "API_TOKEN_PLACEHOLDER" -or
        $config["ApiToken"] -eq "YOUR_API_TOKEN" -or
        $config["ApiToken"] -eq "your-api-token") {
        
        # Set the global flag that we need a token
        $script:ConfigNeedsToken = $true
        
        # Only prompt for token if NoPrompt is not specified
        if (-not $NoPrompt) {
            Write-Host ""
            Write-Host "Your API Token is missing or could not be decrypted." -ForegroundColor Red
            Write-Host "Please enter your Cloudflare API Token now:" -ForegroundColor Yellow
            $newApiToken = Read-Host -AsSecureString "API Token"
            
            if ($newApiToken.Length -gt 0) {
                $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($newApiToken)
                $config["ApiToken"] = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
                [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
                $script:ConfigNeedsToken = $false
                
                # Save the updated config
                if ($config["EncryptionEnabled"]) {
                    Export-CloudflareDDNSSecureConfig -Config $config
                    Write-Output "Saved new API token to secure configuration."
                }
                else {
                    # Save to regular config
                    $config | ConvertTo-Json | Set-Content -Path $configPath -Force
                    Write-Output "Saved new API token to configuration."
                }
            }
            else {
                Write-Host "No API token provided. Some operations may fail." -ForegroundColor Red
                # Keep the placeholder token
            }
        }
    }
    
    # Check if running as SYSTEM
    $isSystem = $false
    try {
        # Try to use Test-RunningAsSystem from AsSystem module if available
        if (Get-Command -Name Test-RunningAsSystem -ErrorAction SilentlyContinue) {
            $isSystem = Test-RunningAsSystem
        }
    }
    catch {
        Write-Verbose "Error checking system status: $_"
    }
    
    # If encryption is enabled but we're not running as SYSTEM, show a warning
    if ($config['EncryptionEnabled'] -and -not $isSystem) {
        Write-Warning "Encryption is enabled but not running as SYSTEM. Some operations may fail."
    }
    
    return $config
}

# Export the configuration to a secure file
function Export-CloudflareDDNSSecureConfig {
    param (
        [Parameter(Mandatory = $true)]
        [object]$Config
    )
    
    # Check if running as SYSTEM, if not, try to elevate
    $isSystem = $false
    try {
        # Try to use Test-RunningAsSystem from AsSystem module if available
        if (Get-Command -Name Test-RunningAsSystem -ErrorAction SilentlyContinue) {
            $isSystem = Test-RunningAsSystem
        }
    }
    catch {
        Write-Verbose "Error checking system status: $_"
    }
    
    if (-not $isSystem) {
        return Invoke-ConfigOperationAsSystem -Operation "Export" -Config $Config
    }
    
    $encryptedConfigPath = Join-Path -Path $Config['ConfigDir'] -ChildPath $script:EncryptedConfigFileName
    
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

# Import the configuration from a secure file
function Import-CloudflareDDNSSecureConfig {
    # Check if running as SYSTEM, if not, try to elevate
    $isSystem = $false
    try {
        # Try to use Test-RunningAsSystem from AsSystem module if available
        if (Get-Command -Name Test-RunningAsSystem -ErrorAction SilentlyContinue) {
            $isSystem = Test-RunningAsSystem
        }
    }
    catch {
        Write-Verbose "Error checking system status: $_"
    }
    
    if (-not $isSystem) {
        return Invoke-ConfigOperationAsSystem -Operation "Import"
    }
    
    $encryptedConfigPath = Join-Path -Path $script:defaultConfig.ConfigDir -ChildPath $script:EncryptedConfigFileName
    
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