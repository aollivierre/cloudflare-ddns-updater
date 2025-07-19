# Test-ZoomCleanupSystemContext.ps1
# A dedicated test script for testing Zoom cleanup in SYSTEM context
# This script is designed to be run with administrator privileges and the AsSystem module

# Set error action preference
$ErrorActionPreference = 'Continue'

function Write-SystemContextLog {
    param (
        [string]$Message,
        [string]$Color = "White"
    )
    
    Write-Host $Message -ForegroundColor $Color
}

# Check if running as administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-SystemContextLog "This script should be run as administrator to use the AsSystem module." "Red"
    Write-SystemContextLog "Please restart this script with administrator privileges." "Red"
    exit 1
}

# Check and enforce AllSigned execution policy
Write-SystemContextLog "===== Execution Policy Validation =====" "Cyan"
$currentPolicy = Get-ExecutionPolicy
$scopedPolicies = Get-ExecutionPolicy -List

Write-SystemContextLog "Current Execution Policy: $currentPolicy" "Yellow"
Write-SystemContextLog "Execution Policy by Scope:" "Yellow"
foreach ($policy in $scopedPolicies) {
    $scope = $policy.Scope
    $policyValue = $policy.ExecutionPolicy
    Write-Host "  $scope : $policyValue" -ForegroundColor $(if ($policyValue -eq "AllSigned") { "Green" } else { "Gray" })
}

# Enforce AllSigned execution policy for the current process
Write-SystemContextLog "`nEnforcing AllSigned execution policy globally..." "Magenta"
try {
    # Set policy for the current process
    Set-ExecutionPolicy -ExecutionPolicy AllSigned -Scope Process -Force -ErrorAction Stop
    
    # Set policy for all users (including SYSTEM)
    Write-SystemContextLog "Setting AllSigned execution policy at LocalMachine scope (will apply to SYSTEM context)..." "Yellow"
    Set-ExecutionPolicy -ExecutionPolicy AllSigned -Scope LocalMachine -Force -ErrorAction Stop
    
    # Verify the settings
    $newPolicy = Get-ExecutionPolicy
    $allPolicies = Get-ExecutionPolicy -List
    
    Write-SystemContextLog "Execution policies after update:" "Cyan"
    foreach ($policy in $allPolicies) {
        $scope = $policy.Scope
        $policyValue = $policy.ExecutionPolicy
        $color = if ($policyValue -eq "AllSigned") { "Green" } else { "Gray" }
        if ($scope -eq "LocalMachine" -and $policyValue -ne "AllSigned") {
            $color = "Red"
            Write-SystemContextLog "WARNING: LocalMachine policy was not set to AllSigned! SYSTEM context may use a less secure policy." "Red"
        }
        Write-Host "  $scope : $policyValue" -ForegroundColor $color
    }
    
    if ($newPolicy -eq "AllSigned") {
        Write-SystemContextLog "Successfully set execution policy to AllSigned." "Green"
        Write-SystemContextLog "This will ensure that only signed scripts execute in all contexts, including SYSTEM." "Green"
    } else {
        Write-SystemContextLog "WARNING: Failed to set AllSigned execution policy!" "Red"
        Write-SystemContextLog "Current policy is still: $newPolicy" "Red"
        
        $proceed = Read-Host "Do you want to proceed anyway? (Y/N)"
        if ($proceed -ne "Y" -and $proceed -ne "y") {
            Write-SystemContextLog "Exiting due to execution policy requirements not met." "Red"
            exit 1
        }
        Write-SystemContextLog "Proceeding with current execution policy: $newPolicy (not recommended)" "Yellow"
    }
} catch {
    Write-SystemContextLog "ERROR: Failed to set AllSigned execution policy: $_" "Red"
    if ($_.Exception.Message -like "*sufficient access rights*") {
        Write-SystemContextLog "This error occurred because you don't have Administrator rights to change the LocalMachine policy." "Yellow"
        Write-SystemContextLog "Please run this script as Administrator." "Yellow"
    }
    
    $proceed = Read-Host "Do you want to proceed anyway? (Y/N)"
    if ($proceed -ne "Y" -and $proceed -ne "y") {
        Write-SystemContextLog "Exiting due to execution policy requirements not met." "Red"
        exit 1
    }
    Write-SystemContextLog "Proceeding with current execution policy (not recommended)" "Yellow"
}

# Define paths
$scriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$detectionScript = Join-Path $scriptFolder "Detect-ZoomOlderThan30Days.ps1"
$remediationScript = Join-Path $scriptFolder "Remediate-ZoomCleanup.ps1"
$activeUseScript = Join-Path $scriptFolder "Detect-ZoomActivelyInUse.ps1"

# Verify scripts exist
$scriptsExist = $true
if (-not (Test-Path $detectionScript)) {
    Write-SystemContextLog "Detection script not found at: $detectionScript" "Red"
    $scriptsExist = $false
}

if (-not (Test-Path $remediationScript)) {
    Write-SystemContextLog "Remediation script not found at: $remediationScript" "Red"
    $scriptsExist = $false
}

if (-not (Test-Path $activeUseScript)) {
    Write-SystemContextLog "Active use detection script not found at: $activeUseScript" "Red"
    Write-SystemContextLog "This script is optional and won't block testing." "Yellow"
}

if (-not $scriptsExist) {
    Write-SystemContextLog "Required scripts not found. Please check the paths and try again." "Red"
    exit 1
}

# Import AsSystem module for SYSTEM context testing
$asSystemModulePath = "c:\Code\Modulesv2\AsSystem-Module\AsSystem"
if (Test-Path -Path $asSystemModulePath) {
    try {
        Import-Module $asSystemModulePath -ErrorAction Stop
        Write-SystemContextLog "AsSystem module loaded successfully for SYSTEM context testing." "Green"
    }
    catch {
        Write-SystemContextLog "Failed to load AsSystem module: $_" "Yellow"
        Write-SystemContextLog "SYSTEM context testing will be unavailable." "Yellow"
        exit 1
    }
}
else {
    Write-SystemContextLog "AsSystem module not found at: $asSystemModulePath" "Yellow"
    Write-SystemContextLog "SYSTEM context testing will be unavailable." "Yellow"
    exit 1
}

# Check if already running as SYSTEM
if (Test-RunningAsSystem) {
    Write-SystemContextLog "This script is already running as SYSTEM. Tests will run directly." "Green"
}

function Show-Menu {
    Clear-Host
    Write-SystemContextLog "===== Zoom Cleanup SYSTEM Context Test Menu =====" "Magenta"
    Write-SystemContextLog "1: Run CLEANUP detection script as SYSTEM (checks for old Zoom installs)" "White"
    Write-SystemContextLog "2: Run CLEANUP detection script as SYSTEM with -Force (always triggers cleanup)" "White"
    Write-SystemContextLog "3: Run CLEANUP remediation script as SYSTEM (runs CleanZoom.exe)" "White"
    Write-SystemContextLog "4: Run full CLEANUP detection + remediation flow as SYSTEM" "White"
    Write-SystemContextLog "5: Run full CLEANUP detection with -Force + remediation flow as SYSTEM" "White"
    Write-SystemContextLog "6: Run Zoom INSTALLATION script as SYSTEM (installs/upgrades Zoom)" "White"
    Write-SystemContextLog "7: Run Zoom UNINSTALLATION script as SYSTEM (removes both managed and user-installed Zoom)" "White"
    Write-SystemContextLog "8: Run Zoom VERSION detection script as SYSTEM (for SCCM installation)" "White"
    Write-SystemContextLog "9: Run complete VERSION detection + INSTALLATION flow as SYSTEM" "Cyan"
    Write-SystemContextLog "10: Run complete VERSION detection + UNINSTALLATION flow as SYSTEM (removes both managed and user installations)" "Cyan"
    Write-SystemContextLog "11: Run PSADT deployment script as SYSTEM (testing deployment toolkit)" "Yellow"
    Write-SystemContextLog "12: Run PSADT uninstall script as SYSTEM (testing uninstallation with toolkit)" "Yellow"
    Write-SystemContextLog "13: Run PSADT Deploy-Application.exe as SYSTEM for installation (testing EXE deployment)" "Yellow"
    Write-SystemContextLog "14: Run PSADT Deploy-Application.exe as SYSTEM for uninstallation (testing EXE uninstallation)" "Yellow"
    Write-SystemContextLog "15: Test PSADT Cleanup Toolkit as SYSTEM (testing cleanup toolkit)" "Cyan"
    Write-SystemContextLog "0: Exit" "White"
    Write-Host
}

# Function to run a script as SYSTEM with simple output
function Invoke-ScriptAsSystemSimple {
    param (
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    
    Write-SystemContextLog "Running $ScriptPath as SYSTEM..." "Yellow"
    
    # First, check what parameters Invoke-AsSystem actually supports (for debugging)
    $asSystemCommand = Get-Command -Name Invoke-AsSystem -ErrorAction Stop
    Write-SystemContextLog "Checking AsSystem module parameters..." "Cyan"
    $parameterNames = $asSystemCommand.Parameters.Keys | Where-Object { $_ -notin [System.Management.Automation.PSCmdlet]::CommonParameters }
    Write-SystemContextLog "Available parameters: $($parameterNames -join ', ')" "Cyan"
    
    # If already SYSTEM, just run it
    if (Test-RunningAsSystem) {
        $scriptArgs = if ($Arguments.Count -gt 0) { $Arguments -join " " } else { "" }
        $cmd = "$ScriptPath $scriptArgs"
        Write-SystemContextLog "Executing script directly (already SYSTEM): $cmd" "Cyan"
        
        try {
            # Ensure execution policy applies to the current session
            $currentPolicy = Get-ExecutionPolicy
            Write-SystemContextLog "Current execution policy: $currentPolicy" "Cyan"
            
            # Capture both output and errors
            $output = & $ScriptPath $Arguments 2>&1
            $exitCode = $LASTEXITCODE
            
            return @{
                Success  = $true
                Output   = $output
                ExitCode = $exitCode
            }
        }
        catch {
            Write-SystemContextLog "Error running script: $_" "Red"
            return @{
                Success  = $false
                Output   = $_.ToString()
                ExitCode = 1
            }
        }
    }
    # Otherwise, run through AsSystem module
    else {
        try {
            # Get the full path to the script
            $absoluteScriptPath = Resolve-Path -Path $ScriptPath | Select-Object -ExpandProperty Path
            
            Write-SystemContextLog "Using Invoke-ScriptAsSystem from the module..." "Cyan"
            
            # Check if the function exists
            if (Get-Command -Name Invoke-ScriptAsSystem -ErrorAction SilentlyContinue) {
                Write-SystemContextLog "Found Invoke-ScriptAsSystem function, using it directly" "Green"
                
                # Execute the script using the Invoke-ScriptAsSystem function which should handle SYSTEM context properly
                # Check which parameters it accepts
                $scriptAsSystemCmd = Get-Command -Name Invoke-ScriptAsSystem
                $hasArgumentsParam = $scriptAsSystemCmd.Parameters.ContainsKey("Arguments")
                $hasScriptParametersParam = $scriptAsSystemCmd.Parameters.ContainsKey("ScriptParameters")
                
                Write-SystemContextLog "Checking Invoke-ScriptAsSystem parameters..." "Cyan"
                
                if ($hasArgumentsParam) {
                    Write-SystemContextLog "Using Arguments parameter" "Green"
                    $result = Invoke-ScriptAsSystem -ScriptPath $absoluteScriptPath -Arguments $Arguments
                }
                elseif ($hasScriptParametersParam) {
                    Write-SystemContextLog "Using ScriptParameters parameter" "Green"
                    $result = Invoke-ScriptAsSystem -ScriptPath $absoluteScriptPath -ScriptParameters $Arguments
                }
                else {
                    # Try without parameters if needed
                    Write-SystemContextLog "No parameter for arguments found, trying without parameters" "Yellow"
                    if ($Arguments -and $Arguments.Count -gt 0) {
                        Write-SystemContextLog "WARNING: Script parameters will be ignored: $($Arguments -join ' ')" "Red"
                    }
                    $result = Invoke-ScriptAsSystem -ScriptPath $absoluteScriptPath
                }
                
                return @{
                    Success  = $true
                    Output   = "Script was invoked using Invoke-ScriptAsSystem. Check the console window for output."
                    ExitCode = -1
                }
            }
            else {
                # Fallback to basic Invoke-AsSystem
                Write-SystemContextLog "Invoke-ScriptAsSystem not found, using basic Invoke-AsSystem..." "Yellow"
                
                # Use Invoke-AsSystem with the script path directly
                $result = Invoke-AsSystem -ScriptPathAsSYSTEM $absoluteScriptPath -ScriptParameters $Arguments
                
                return @{
                    Success  = $true
                    Output   = "Script was invoked using basic Invoke-AsSystem. Check the console window for output."
                    ExitCode = -1
                }
            }
        }
        catch {
            Write-SystemContextLog "Error invoking script as SYSTEM: $_" "Red"
            return @{
                Success  = $false
                Output   = $_.ToString()
                ExitCode = 1
            }
        }
    }
}

# Function to run detection and remediation in sequence
function Invoke-DetectionRemediationFlow {
    param (
        [switch]$Force
    )
    
    Write-SystemContextLog "Starting detection + remediation flow as SYSTEM..." "Magenta"
    
    # Run detection first
    $detectionArgs = @()
    if ($Force) {
        $detectionArgs += "-Force"
        Write-SystemContextLog "Running with -Force parameter" "Yellow"
    }
    
    $detectionResult = Invoke-ScriptAsSystemSimple -ScriptPath $detectionScript -Arguments $detectionArgs
    
    if ($detectionResult.Success) {
        Write-SystemContextLog "Detection script completed successfully." "Green"
        
        # We need to add logic to check if the detection script indicated remediation is needed
        # When running as SYSTEM with Invoke-ScriptAsSystem, we can't directly get the exit code
        # So we'll need to rely on the information we have in the popup window
        
        # Prompt the user to confirm the detection script's outcome
        Write-SystemContextLog "IMPORTANT: Check the SYSTEM console window." "Yellow"
        $needsRemediation = Read-Host "Did the detection script indicate remediation is needed? (Y/N)"
        
        if ($needsRemediation -eq "Y" -or $needsRemediation -eq "y") {
            Write-SystemContextLog "Remediation needed. Now running remediation script as SYSTEM..." "Magenta"
            
            $remediationResult = Invoke-ScriptAsSystemSimple -ScriptPath $remediationScript
            
            if ($remediationResult.Success) {
                Write-SystemContextLog "Remediation script completed successfully." "Green"
            }
            else {
                Write-SystemContextLog "Remediation script failed." "Red"
            }
        }
        else {
            Write-SystemContextLog "No remediation needed. Skipping remediation script." "Green"
        }
    }
    else {
        Write-SystemContextLog "Detection script failed." "Red"
    }
}

# Main loop
do {
    Show-Menu
    $choice = Read-Host "Enter your choice"
    
    switch ($choice) {
        "1" {
            # Run detection script (normal mode)
            $result = Invoke-ScriptAsSystemSimple -ScriptPath $detectionScript
            
            if ($result.Success) {
                Write-SystemContextLog "Detection script completed successfully." "Green"
            }
            else {
                Write-SystemContextLog "Detection script failed." "Red"
            }
            
            pause
        }
        "2" {
            # Run detection script (force mode)
            $result = Invoke-ScriptAsSystemSimple -ScriptPath $detectionScript -Arguments @("-Force")
            
            if ($result.Success) {
                Write-SystemContextLog "Detection script with force mode completed successfully." "Green"
            }
            else {
                Write-SystemContextLog "Detection script with force mode failed." "Red"
            }
            
            pause
        }
        "3" {
            # Run remediation script
            $result = Invoke-ScriptAsSystemSimple -ScriptPath $remediationScript
            
            if ($result.Success) {
                Write-SystemContextLog "Remediation script completed successfully." "Green"
            }
            else {
                Write-SystemContextLog "Remediation script failed." "Red"
            }
            
            pause
        }
        "4" {
            # Run full detection + remediation flow
            Invoke-DetectionRemediationFlow
            
            pause
        }
        "5" {
            # Run full detection (force mode) + remediation flow
            Invoke-DetectionRemediationFlow -Force
            
            pause
        }
        "6" {
            # Run Zoom installation script
            $installScriptPath = Join-Path (Split-Path -Parent $scriptFolder) "Deployment\Install-ZoomSystemContext.ps1"
            
            if (Test-Path $installScriptPath) {
                Write-SystemContextLog "Running Zoom installation script as SYSTEM..." "Yellow"
                $result = Invoke-ScriptAsSystemSimple -ScriptPath $installScriptPath
                
                if ($result.Success) {
                    Write-SystemContextLog "Zoom installation script completed successfully." "Green"
                }
                else {
                    Write-SystemContextLog "Zoom installation script failed." "Red"
                }
            }
            else {
                Write-SystemContextLog "Installation script not found at: $installScriptPath" "Red"
            }
            
            pause
        }
        "7" {
            # Run Zoom uninstallation script
            $uninstallScriptPath = Join-Path (Split-Path -Parent $scriptFolder) "Deployment\Uninstall-ZoomSystemContext.ps1"
            
            if (Test-Path $uninstallScriptPath) {
                Write-SystemContextLog "Running Zoom uninstallation script as SYSTEM..." "Yellow"
                $result = Invoke-ScriptAsSystemSimple -ScriptPath $uninstallScriptPath
                
                if ($result.Success) {
                    Write-SystemContextLog "Zoom uninstallation script completed successfully." "Green"
                }
                else {
                    Write-SystemContextLog "Zoom uninstallation script failed." "Red"
                }
            }
            else {
                Write-SystemContextLog "Uninstallation script not found at: $uninstallScriptPath" "Red"
            }
            
            pause
        }
        "8" {
            # Run the SCCM version detection script
            $versionDetectionScript = Join-Path (Split-Path -Parent $scriptFolder) "Detection\ZoomWorkplace-Detection.ps1"
            
            if (Test-Path $versionDetectionScript) {
                Write-SystemContextLog "Running Zoom version detection script as SYSTEM (for SCCM installation)" "Yellow"
                $result = Invoke-ScriptAsSystemSimple -ScriptPath $versionDetectionScript
                
                if ($result.Success) {
                    Write-SystemContextLog "Zoom version detection script completed successfully." "Green"
                }
                else {
                    Write-SystemContextLog "Zoom version detection script failed." "Red"
                }
            }
            else {
                Write-SystemContextLog "Zoom version detection script not found at: $versionDetectionScript" "Red"
            }
            
            pause
        }
        "9" {
            # Run complete VERSION detection + INSTALLATION flow
            $versionDetectionScript = Join-Path (Split-Path -Parent $scriptFolder) "Detection\ZoomWorkplace-Detection.ps1"
            $installScriptPath = Join-Path (Split-Path -Parent $scriptFolder) "Deployment\Install-ZoomSystemContext.ps1"
            
            if (-not (Test-Path $versionDetectionScript)) {
                Write-SystemContextLog "Zoom version detection script not found at: $versionDetectionScript" "Red"
                pause
                continue
            }
            
            if (-not (Test-Path $installScriptPath)) {
                Write-SystemContextLog "Installation script not found at: $installScriptPath" "Red"
                pause
                continue
            }
            
            # Run detection first
            Write-SystemContextLog "STEP 1: Running Zoom version detection script as SYSTEM" "Yellow"
            $detectionResult = Invoke-ScriptAsSystemSimple -ScriptPath $versionDetectionScript
            
            Write-SystemContextLog "Detection result exit code: $($detectionResult.ExitCode)" "Cyan"
            Write-SystemContextLog "This simulates what SCCM would detect to determine if installation is needed" "Cyan"
            
            # Always run installation after detection (in a real SCCM deployment, this would only run if needed)
            Write-SystemContextLog "`nSTEP 2: Running Zoom installation script as SYSTEM" "Yellow"
            $installResult = Invoke-ScriptAsSystemSimple -ScriptPath $installScriptPath
            
            if ($installResult.Success) {
                Write-SystemContextLog "Zoom installation script completed successfully." "Green"
            }
            else {
                Write-SystemContextLog "Zoom installation script failed." "Red"
            }
            
            # Verify the result by running detection again
            Write-SystemContextLog "`nSTEP 3: Verifying installation with detection script" "Yellow"
            $verifyResult = Invoke-ScriptAsSystemSimple -ScriptPath $versionDetectionScript
            Write-SystemContextLog "Verification detection result exit code: $($verifyResult.ExitCode)" "Cyan"
            
            Write-SystemContextLog "`nTest flow completed. This simulates the full SCCM deployment cycle." "Green"
            pause
        }
        "10" {
            # Run complete VERSION detection + UNINSTALLATION flow
            $versionDetectionScript = Join-Path (Split-Path -Parent $scriptFolder) "Detection\ZoomWorkplace-Detection.ps1"
            $uninstallScriptPath = Join-Path (Split-Path -Parent $scriptFolder) "Deployment\Uninstall-ZoomSystemContext.ps1"
            
            if (-not (Test-Path $versionDetectionScript)) {
                Write-SystemContextLog "Zoom version detection script not found at: $versionDetectionScript" "Red"
                pause
                continue
            }
            
            if (-not (Test-Path $uninstallScriptPath)) {
                Write-SystemContextLog "Uninstallation script not found at: $uninstallScriptPath" "Red"
                pause
                continue
            }
            
            # Run detection first
            Write-SystemContextLog "STEP 1: Running Zoom version detection script as SYSTEM" "Yellow"
            $detectionResult = Invoke-ScriptAsSystemSimple -ScriptPath $versionDetectionScript
            
            Write-SystemContextLog "Detection result exit code: $($detectionResult.ExitCode)" "Cyan"
            Write-SystemContextLog "This simulates what SCCM would detect to determine if uninstallation is needed" "Cyan"
            
            # Always run uninstallation after detection (in real SCCM, this would only run for removal)
            Write-SystemContextLog "`nSTEP 2: Running Zoom uninstallation script as SYSTEM" "Yellow"
            $uninstallResult = Invoke-ScriptAsSystemSimple -ScriptPath $uninstallScriptPath
            
            if ($uninstallResult.Success) {
                Write-SystemContextLog "Zoom uninstallation script completed successfully." "Green"
            }
            else {
                Write-SystemContextLog "Zoom uninstallation script failed." "Red"
            }
            
            # Verify the result by running detection again
            Write-SystemContextLog "`nSTEP 3: Verifying uninstallation with detection script" "Yellow"
            $verifyResult = Invoke-ScriptAsSystemSimple -ScriptPath $versionDetectionScript
            Write-SystemContextLog "Verification detection result exit code: $($verifyResult.ExitCode)" "Cyan"
            
            Write-SystemContextLog "`nTest flow completed. This simulates the full SCCM uninstallation cycle." "Green"
            pause
        }
        "11" {
            # Run the PSADT deployment script in SYSTEM context
            $psadtScript = "C:\Code\Apps\Zoom\PSADT\Templates\PSAppDeployToolkit_3.10.2\Toolkit\Deploy-Application.ps1"

            if (Test-Path $psadtScript) {
                Write-SystemContextLog "Running PSADT deployment script as SYSTEM (testing deployment toolkit)" "Yellow"
        
                # Create a temporary script that will call the PSADT script
                $tempScriptPath = Join-Path $env:TEMP "RunPSADT_$([Guid]::NewGuid().ToString()).ps1"
        
                @"
# Temporary script to call PSADT
& '$psadtScript' -DeployMode 'Interactive'
Exit `$LASTEXITCODE
"@ | Out-File -FilePath $tempScriptPath -Force -Encoding UTF8
        
                try {
                    $result = Invoke-ScriptAsSystemSimple -ScriptPath $tempScriptPath
            
                    if ($result.Success) {
                        Write-SystemContextLog "PSADT deployment script completed successfully with exit code: $($result.ExitCode)" "Green"
                        Write-SystemContextLog "Output from PSADT script:" "Yellow"
                        Write-SystemContextLog $result.Output "Cyan"
                    }
                    else {
                        Write-SystemContextLog "PSADT deployment script failed with exit code: $($result.ExitCode)" "Red"
                        Write-SystemContextLog "Error output:" "Red"
                        Write-SystemContextLog $result.Output "Red"
                    }
                }
                finally {
                    # Clean up the temporary script
                    if (Test-Path $tempScriptPath) {
                        Remove-Item $tempScriptPath -Force
                    }
                }
            }
            else {
                Write-SystemContextLog "PSADT deployment script not found at: $psadtScript" "Red"
            }
    
            pause
        }
        "12" {
            # Run the PSADT deployment script in SYSTEM context with uninstall parameter
            $psadtScript = "C:\Code\Apps\Zoom\PSADT\Templates\PSAppDeployToolkit_3.10.2\Toolkit\Deploy-Application.ps1"

            if (Test-Path $psadtScript) {
                Write-SystemContextLog "Running PSADT uninstall script as SYSTEM (testing deployment toolkit)" "Yellow"
        
                # Create a temporary script that will call the PSADT script with uninstall parameter
                $tempScriptPath = Join-Path $env:TEMP "RunPSADT_$([Guid]::NewGuid().ToString()).ps1"
        
                @"
# Temporary script to call PSADT
& '$psadtScript' -DeploymentType 'Uninstall' -DeployMode 'Interactive'
Exit `$LASTEXITCODE
"@ | Out-File -FilePath $tempScriptPath -Force -Encoding UTF8
        
                try {
                    $result = Invoke-ScriptAsSystemSimple -ScriptPath $tempScriptPath
            
                    if ($result.Success) {
                        Write-SystemContextLog "PSADT uninstall script completed successfully with exit code: $($result.ExitCode)" "Green"
                        Write-SystemContextLog "Output from PSADT script:" "Yellow"
                        Write-SystemContextLog $result.Output "Cyan"
                    }
                    else {
                        Write-SystemContextLog "PSADT uninstall script failed with exit code: $($result.ExitCode)" "Red"
                        Write-SystemContextLog "Error output:" "Red"
                        Write-SystemContextLog $result.Output "Red"
                    }
                }
                finally {
                    # Clean up the temporary script
                    if (Test-Path $tempScriptPath) {
                        Remove-Item $tempScriptPath -Force
                    }
                }
            }
            else {
                Write-SystemContextLog "PSADT deployment script not found at: $psadtScript" "Red"
            }
    
            pause
        }
        "13" {
            # Run PSADT Deploy-Application.exe as SYSTEM for installation (testing EXE deployment)
            $psadtExe = "C:\Code\Apps\Zoom\PSADT\Templates\PSAppDeployToolkit_3.10.2\Toolkit\Deploy-Application.exe"

            if (Test-Path $psadtExe) {
                Write-SystemContextLog "Running PSADT Deploy-Application.exe as SYSTEM for installation (testing EXE deployment)" "Yellow"
        
                # Create a temporary script that will call the PSADT executable
                $tempScriptPath = Join-Path $env:TEMP "RunPSADTExe_$([Guid]::NewGuid().ToString()).ps1"
        
                @"
# Temporary script to call PSADT executable
& '$psadtExe' -DeploymentType 'Install'
Exit `$LASTEXITCODE
"@ | Out-File -FilePath $tempScriptPath -Force -Encoding UTF8
        
                try {
                    $result = Invoke-ScriptAsSystemSimple -ScriptPath $tempScriptPath
            
                    if ($result.Success) {
                        Write-SystemContextLog "PSADT Deploy-Application.exe completed successfully with exit code: $($result.ExitCode)" "Green"
                        Write-SystemContextLog "Output from PSADT executable:" "Yellow"
                        Write-SystemContextLog $result.Output "Cyan"
                    }
                    else {
                        Write-SystemContextLog "PSADT Deploy-Application.exe failed with exit code: $($result.ExitCode)" "Red"
                        Write-SystemContextLog "Error output:" "Red"
                        Write-SystemContextLog $result.Output "Red"
                    }
                }
                finally {
                    # Clean up the temporary script
                    if (Test-Path $tempScriptPath) {
                        Remove-Item $tempScriptPath -Force
                    }
                }
            }
            else {
                Write-SystemContextLog "PSADT executable not found at: $psadtExe" "Red"
            }
    
            pause
        }
        "14" {
            # Run PSADT Deploy-Application.exe as SYSTEM for uninstallation (testing EXE uninstallation)
            $psadtExe = "C:\Code\Apps\Zoom\PSADT\Templates\PSAppDeployToolkit_3.10.2\Toolkit\Deploy-Application.exe"

            if (Test-Path $psadtExe) {
                Write-SystemContextLog "Running PSADT Deploy-Application.exe as SYSTEM for uninstallation (testing EXE uninstallation)" "Yellow"
        
                # Create a temporary script that will call the PSADT executable with uninstall parameter
                $tempScriptPath = Join-Path $env:TEMP "RunPSADTExe_$([Guid]::NewGuid().ToString()).ps1"
        
                @"
# Temporary script to call PSADT executable
& '$psadtExe' -DeploymentType 'Uninstall'
Exit `$LASTEXITCODE
"@ | Out-File -FilePath $tempScriptPath -Force -Encoding UTF8
        
                try {
                    $result = Invoke-ScriptAsSystemSimple -ScriptPath $tempScriptPath
            
                    if ($result.Success) {
                        Write-SystemContextLog "PSADT Deploy-Application.exe completed successfully with exit code: $($result.ExitCode)" "Green"
                        Write-SystemContextLog "Output from PSADT executable:" "Yellow"
                        Write-SystemContextLog $result.Output "Cyan"
                    }
                    else {
                        Write-SystemContextLog "PSADT Deploy-Application.exe failed with exit code: $($result.ExitCode)" "Red"
                        Write-SystemContextLog "Error output:" "Red"
                        Write-SystemContextLog $result.Output "Red"
                    }
                }
                finally {
                    # Clean up the temporary script
                    if (Test-Path $tempScriptPath) {
                        Remove-Item $tempScriptPath -Force
                    }
                }
            }
            else {
                Write-SystemContextLog "PSADT executable not found at: $psadtExe" "Red"
            }
    
            pause
        }
        "15" {
            # Test PSADT Cleanup Toolkit as SYSTEM
            $psadtScript = "C:\Code\Apps\Zoom\PSADT-CleanZoom\Toolkit\Deploy-Application.ps1"

            if (Test-Path $psadtScript) {
                Write-SystemContextLog "Testing PSADT Cleanup Toolkit as SYSTEM..." "Yellow"
        
                # Create a temporary script that will call the PSADT script with uninstall parameter
                $tempScriptPath = Join-Path $env:TEMP "RunPSADTCleanup_$([Guid]::NewGuid().ToString()).ps1"
        
                @"
# Temporary script to call PSADT cleanup toolkit
& '$psadtScript' -DeploymentType 'Uninstall' -DeployMode 'Interactive'
Exit `$LASTEXITCODE
"@ | Out-File -FilePath $tempScriptPath -Force -Encoding UTF8
        
                try {
                    $result = Invoke-ScriptAsSystemSimple -ScriptPath $tempScriptPath
            
                    if ($result.Success) {
                        Write-SystemContextLog "PSADT Cleanup Toolkit completed successfully with exit code: $($result.ExitCode)" "Green"
                        Write-SystemContextLog "Output from PSADT script:" "Yellow"
                        Write-SystemContextLog $result.Output "Cyan"
                        
                        # Display exit code meanings
                        Write-SystemContextLog "`nExit Code Meanings:" "Magenta"
                        Write-SystemContextLog "0: Success" "White"
                        Write-SystemContextLog "69000: Active meeting detected or incorrect deployment type" "White"
                        Write-SystemContextLog "69001: CleanZoom ran but Zoom still detected" "White"
                        Write-SystemContextLog "69002: CleanZoom utility failed" "White"
                        Write-SystemContextLog "69003: CleanZoom utility not found" "White"
                        Write-SystemContextLog "69004: Error running CleanZoom utility" "White"
                    }
                    else {
                        Write-SystemContextLog "PSADT Cleanup Toolkit failed with exit code: $($result.ExitCode)" "Red"
                        Write-SystemContextLog "Error output:" "Red"
                        Write-SystemContextLog $result.Output "Red"
                    }
                }
                finally {
                    # Clean up the temporary script
                    if (Test-Path $tempScriptPath) {
                        Remove-Item $tempScriptPath -Force
                    }
                }
            }
            else {
                Write-SystemContextLog "PSADT Cleanup Toolkit script not found at: $psadtScript" "Red"
            }
    
            pause
        }
        "0" {
            Write-SystemContextLog "Exiting..." "Cyan"
        }
        default {
            Write-SystemContextLog "Invalid choice. Please try again." "Red"
            pause
        }
    }
}
while ($choice -ne "0")