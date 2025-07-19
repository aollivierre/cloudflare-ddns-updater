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
                $configPath = Join-Path -Path $Config.ConfigDir -ChildPath $script:ConfigFileName
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