# KeepAwake PowerShell Script

This folder contains a PowerShell script that prevents your Windows system from going to sleep. It provides a more robust and system-friendly approach compared to traditional key-simulation methods.

## Overview

### Previous Approach (Key Simulation)
The original script used WScript.Shell to simulate keyboard input:

```powershell
$wsh = New-Object -ComObject WScript.Shell
while (1) {
    $wsh.SendKeys('+{F15}')
    Start-Sleep -seconds 59
}
```

**Issues with this approach:**
- Interferes with actual keyboard input
- Potentially triggers NumLock changes
- May conflict with other applications
- Higher system overhead
- Less reliable
- Can interfere with user input
- No proper error handling or logging
- No clean way to restore system state

### New Approach (Windows API)
The improved version uses the Windows API directly through `SetThreadExecutionState`:

```powershell
[DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
public static extern ulong SetThreadExecutionState(ulong esFlags);
```

**Advantages:**
- Uses official Windows API
- No interference with user input
- More reliable and efficient
- Proper system state management
- Includes logging functionality
- Clean error handling
- Proper cleanup on exit
- Status monitoring capabilities
- Professional implementation

## Features

- Prevents system sleep
- Prevents display sleep
- Status indicators (optional)
- Activity logging
- Clean exit handling
- Duration tracking
- Error handling and reporting
- Multi-user support
- Invisible operation (no console window)
- Log checking utility
- Scheduled task for automatic startup

## Requirements

- Windows operating system
- PowerShell 5.1 or later

## Usage

1. Save the script as `KeepAwake.ps1`
2. Run it using:
```powershell
.\KeepAwake.ps1
```

Optional parameters:
- `-ShowStatus`: Displays running status and duration
- `-LogPath`: Specify custom log file location

## How It Works

The script uses the Windows `SetThreadExecutionState` API to tell the system that it should stay awake. It combines several flags:

- `ES_CONTINUOUS` (0x80000000): Maintains the current state until the next call
- `ES_SYSTEM_REQUIRED` (0x00000001): Prevents system sleep
- `ES_DISPLAY_REQUIRED` (0x00000002): Prevents display sleep
- `ES_AWAYMODE_REQUIRED` (0x00000040): Additional flag for more aggressive sleep prevention

## Logging

The script maintains a log file containing:
- Start time
- Stop time
- Duration
- Any errors encountered
- System information (added in latest version)
- Process ID
- Regular status updates

Default log locations:
- When running as a regular user: `$env:USERPROFILE\KeepAwake.log` (e.g., `C:\Users\username\KeepAwake.log`)
- When running as SYSTEM: `C:\Windows\Temp\KeepAwakeSystem.log`

## Stopping the Script

Press `Ctrl+C` to stop the script. It will:
1. Restore default system power settings
2. Log the stop time and duration
3. Display summary if `-ShowStatus` was enabled

## Technical Details

### State Management
The script properly manages system states by:
1. Setting required flags on startup
2. Maintaining the state while running
3. Restoring original state on exit

### Error Handling
- Validates API calls
- Catches and logs errors
- Ensures clean exit even on failure
- Prevents type loading conflicts

## Best Practices

1. Use `-ShowStatus` for visual confirmation
2. Check logs for any issues
3. Always use `Ctrl+C` to exit properly
4. Run with appropriate permissions

## Technical Implementation

The script uses several advanced PowerShell features:
- P/Invoke for Windows API access
- Advanced function parameters
- Error handling and logging
- Type management
- Event handling

## Comparison with Alternative Solutions

### Caffeinate-like Tools
- More lightweight than third-party tools
- No installation required
- No security concerns
- Native PowerShell implementation

### Traditional Scripts
- More reliable than key simulation
- Lower system impact
- Better maintainability
- Professional implementation

## Security Considerations

- No elevated privileges required
- No keyboard simulation security risks
- Clean and auditable code
- No external dependencies

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License - Feel free to use and modify as needed.

## Automatic Startup with Scheduled Task

A new feature has been added to run KeepAwake automatically when Windows starts, even before any user logs in:

### New Files Added

1. **KeepAwakeSystem.ps1**: 
   - An enhanced version of KeepAwake.ps1 optimized for the SYSTEM context
   - Includes built-in detection of SYSTEM context
   - Automatically adjusts its behavior based on whether it's running as SYSTEM or a regular user
   - Provides comprehensive logging to a file
   - Detects when running as SYSTEM and disables console output accordingly

2. **SetupKeepAwakeTask.ps1**:
   - Creates a scheduled task to run KeepAwakeSystem.ps1 at system startup
   - Sets up the task to run with SYSTEM privileges
   - Configures the task to run before any user logs in (at the login screen)
   - Ensures the task continues even on battery power

3. **Test-SystemKeepAwake.ps1**:
   - For testing purposes - allows you to test KeepAwakeSystem.ps1 in the SYSTEM context
   - Downloads PsExec if not available
   - Launches the KeepAwakeSystem.ps1 script as SYSTEM for testing

4. **Check-KeepAwakeLog.ps1**:
   - Utility script to check the status of KeepAwake tasks and logs
   - Automatically finds log files across all user profiles
   - Shows task status and runtime information
   - Can verify if power requests are active
   - Provides options to restart the task or run KeepAwake manually
   - Handles multi-user scenarios with clear warnings
   - Compatible with both PowerShell 5.1 and PowerShell 7 (see PowerShell Compatibility section below)

5. **KeepAwakeInvisible.vbs**:
   - VBScript wrapper to run the PowerShell script invisibly
   - Used to prevent console windows from showing
   - Provides a cleaner user experience

6. **Update-KeepAwakeTask.ps1**:
   - Updates the scheduled task to run invisibly
   - Modifies the task to use the VBScript wrapper
   - Maintains all other task settings

7. **Run-KeepAwakeInvisible.ps1**:
   - Alternative method to run KeepAwake invisibly
   - Doesn't require admin rights
   - Creates a temporary VBScript wrapper

### Installation Steps

1. **Set up the scheduled task**:
   ```powershell
   # Run as Administrator
   .\SetupKeepAwakeTask.ps1
   ```

2. **Make the task run invisibly (optional)**:
   ```powershell
   # Run as Administrator
   .\Update-KeepAwakeTask.ps1
   ```

3. **Check logs and task status**:
   ```powershell
   .\Check-KeepAwakeLog.ps1
   ```

4. **Features of the scheduled task**:
   - Runs automatically at user logon
   - Runs for any user who logs in
   - Continues running even when on battery power
   - Can run invisibly without showing a console window
   - Persists across reboots

5. **How it works**:
   - Uses the Windows API `SetThreadExecutionState` directly
   - Creates a scheduled task that runs at user logon
   - Uses the Windows Task Scheduler for persistence
   - No manual startup needed after installation
   - Persists across reboots

## PowerShell Compatibility

### PowerShell 5.1 and 7.x Compatibility Issues

The scripts were designed to work with both PowerShell 5.1 (which comes with Windows) and PowerShell 7.x (the newer cross-platform version). However, there are some key differences in how these versions handle collections and objects:

1. **Collection Handling Differences**:
   - In PowerShell 5.1, collections retrieved from hashtable properties can lose their array behavior
   - The `@()` array conversion operator does not reliably re-arrayify these collections in PS5.1
   - This can cause objects to be found but not displayed properly in scripts like Check-KeepAwakeLog.ps1

2. **WMI Object Method Access**:
   - PowerShell 5.1 uses `Get-WmiObject` which has different type serialization than PowerShell 7's `Get-CimInstance`
   - Method calls that work in one version may fail in another due to these differences

### Compatibility Fixes Implemented

The following fixes have been implemented to ensure the scripts work in both PowerShell versions:

1. **Array Handling in Check-KeepAwakeLog.ps1**:
   - Replaced standard array initialization with `[System.Collections.ArrayList]::new()`
   - Explicitly adds each log file to the collection using `.Add()` method
   - Preserves type information when sorting collections
   - Ensures proper enumeration of collections across PowerShell versions

2. **Process Owner Checking**:
   - Implements version-specific code paths:
     - Uses `Get-CimInstance` for PowerShell 6+ 
     - Uses `Get-WmiObject` for PowerShell 5.1
   - Each approach accesses process owner information in the way appropriate for that PowerShell version

These fixes ensure that log files are properly displayed in the UI regardless of which PowerShell version you're using, and process owner checking works correctly in both environments.

## Troubleshooting

1. **Log file locations**:
   - When running as a regular user: `$env:USERPROFILE\KeepAwake.log` (e.g., `C:\Users\username\KeepAwake.log`)
   - When running as SYSTEM: `C:\Windows\Temp\KeepAwakeSystem.log`
   - Use `Check-KeepAwakeLog.ps1` to automatically find logs across the system

## Known Issues and Future Improvements

### PowerShell 5.1 Log Display Issues

The `Check-KeepAwakeLog.ps1` script has a confirmed issue displaying log files when run in PowerShell 5.1:

**Current Status:**
- **UNRESOLVED**: In PowerShell 5.1, log files are found but NOT displayed in the UI list
- **WORKING**: In PowerShell 7, log files are correctly found AND displayed
- Our attempted fix (explicit array handling and null checks) didn't resolve the PS5.1 issue

**Technical Notes:**
- Debug output shows logs are being detected correctly
- The issue appears related to how PowerShell 5.1 handles collections returned from hashtables
- Our current implementation with array initialization and null checks doesn't fully address the problem
- The issue seems specific to PS5.1's handling of custom objects in collections

**Recommended Workaround:**
- **Always use PowerShell 7 to run the Check-KeepAwakeLog.ps1 script**
- This is the simplest and most reliable solution
- If PowerShell 7 is not available, we will need to develop a more robust fix in a future update

**Future Development Plan:**
- Complete redesign of the log finding mechanism specifically for PS5.1 compatibility
- Implement a PS5.1-specific branch in the code with different collection handling
- Explore using different data structures (ArrayList, generic List<T>)
- Test native PowerShell collections vs custom objects
- Add explicit [PSCustomObject] type definitions with strong typing

## Setup Instructions

### One-Step Setup (Recommended)

For a simple installation experience, use our combined setup script that handles everything in one step:

```powershell
# Run as Administrator
.\Setup-KeepAwakeComplete.ps1
```

This script will:
1. Check for administrator privileges
2. Prompt you to choose whether to run KeepAwake invisibly (no console window) or visibly (with console window)
3. Find the appropriate KeepAwake script in your directory
4. Create the necessary VBScript wrapper if you choose invisible mode
5. Create or update the scheduled task with all the correct settings
6. Offer to start the task immediately

This is the recommended approach for all new installations.

### Manual Setup (Alternative)

If you prefer to set up the system in separate steps:

1. First create the basic scheduled task:
   ```powershell
   # Run as Administrator
   .\SetupKeepAwakeTask.ps1
   ```

2. Then make it run invisibly (optional):
   ```powershell
   # Run as Administrator
   .\Update-KeepAwakeTask.ps1
   ```

## Monitoring and Management

To check the status of KeepAwake:

```powershell
.\Check-KeepAwakeLog.ps1
```

This utility will:
- Find all available log files across user profiles
- Show you the task status and running processes
- Verify if power requests are active
- Allow you to restart the task or run it manually
- Help troubleshoot any issues with clear status messages

## Best Practices

1. **Installation**:
   - Always use `Setup-KeepAwakeComplete.ps1` for new installations
   - Run as administrator during setup
   - Choose "invisible" mode for normal operation to avoid console windows

2. **Verification**:
   - Use `Check-KeepAwakeLog.ps1` to verify the task is running correctly
   - Check that logs are being updated regularly
   - Verify that power requests are active

3. **Troubleshooting**:
   - If the console window appears despite choosing invisible mode, rerun setup and choose invisible again
   - If no logs are found, ensure you're running as the same user as the task
   - For a quick test, use the manual start option in the log checker utility

4. **Uninstallation**:
   - Open Task Scheduler and delete the "KeepAwakeTask" task
   - Delete the log files if no longer needed

## Technical Details