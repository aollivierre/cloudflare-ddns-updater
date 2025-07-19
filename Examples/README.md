# RD Gateway Hosts Manager

A PowerShell solution for automatically managing RD Gateway hosts file entries based on network location. This script ensures seamless Remote Desktop connectivity by dynamically updating hosts file entries when switching between home and remote networks.

## Features

- **Automatic Network Detection**: Identifies when you're on the home network (198.18.1.x) vs remote
- **Smart Hosts File Management**: 
  - Adds/updates hosts entry when on home network
  - Comments entry when away from home network (preserves entry for when you return)
  - Prevents duplicate entries
  - Preserves other hosts file content
- **Advanced File Lock Detection**:
  - Uses Sysinternals Handle.exe to detect file locks
  - Identifies processes locking the hosts file
  - Graceful fallback if Handle.exe is unavailable
- **Hosts File Editor**:
  - Built-in capability to view/edit the hosts file safely
  - Warns about existing locks before opening
  - Integrates with Notepad for convenient editing
  - Offers DNS cache flushing after edits
- **DNS Management**:
  - Automatic DNS cache flushing after changes
  - DNS resolution verification
- **Comprehensive Scheduling**:
  - Multiple trigger events for reliable operation
  - Network change detection via Windows Events
  - Regular health checks
- **Robust Logging**:
  - Detailed timestamped logs in centralized location
  - Color-coded console output
  - Log file viewer built-in
  - Log rotation and management
  - Fallback logging mechanisms

## Prerequisites

- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or later
- Administrator privileges
- Internet access (for Handle.exe download, first run only)

## Installation

1. Download the `2-Manage-RDGatewayHosts.ps1` script
2. Open PowerShell as Administrator
3. Navigate to the script directory
4. Run the script:
   ```powershell
   .\2-Manage-RDGatewayHosts.ps1
   ```

## Configuration

The script uses the following default settings which can be modified at the top of the script:

```powershell
$GatewayFQDN = "rdgateway02.cloudcommand.org"
$GatewayIP = "198.18.1.109"
$HomeNetworkPrefix = "198.18.1"
$LogFile = "$env:ProgramData\RDGatewayHosts\RDGatewayHosts.log"
```

## Usage

### Interactive Mode
Run the script without parameters to access the interactive menu:
```powershell
.\2-Manage-RDGatewayHosts.ps1
```

### Silent Mode
For scheduled task execution:
```powershell
.\2-Manage-RDGatewayHosts.ps1 -Silent
```

### Install Scheduled Task
To set up automatic monitoring:
```powershell
.\2-Manage-RDGatewayHosts.ps1 -InstallTask
```

### View/Edit Hosts File
To access the hosts file editor directly:
```powershell
.\2-Manage-RDGatewayHosts.ps1
```
Then select option 5 from the menu.

## Scheduled Task Details

The script creates a scheduled task named "RD Gateway Hosts Manager" with the following triggers:

1. **User Logon**: Runs when any user logs on
2. **Regular Check**: Every 15 minutes
3. **Quick Check**: Every minute for rapid network change detection
4. **Startup**: Runs 1 minute after system startup
5. **Network Events**:
   - Network Profile Connected (EventID 10000)
   - Network Profile Disconnected (EventID 10001)
   - Network Adapter Disconnected (EventID 4202)

## Logging

Logs are stored in a central location: `C:\ProgramData\RDGatewayHosts\RDGatewayHosts.log`

View logs through:
- The interactive menu (Option 3)
- Direct file access
- Emergency logs (in case of issues) at `%TEMP%\RDGatewayHosts.emergency.log`

## File Lock Detection

The script uses multiple methods to detect and handle file locks:

1. **Sysinternals Handle.exe**: 
   - Automatically downloaded on first run
   - 64-bit version used on 64-bit systems
   - Provides detailed process information

2. **Fallback Method**:
   - File stream check if Handle.exe unavailable
   - Detects common applications that might lock the file

## Troubleshooting

1. **Script Won't Run**:
   - Ensure you have Administrator privileges
   - Check PowerShell execution policy
   - Verify script path in scheduled task

2. **Network Detection Issues**:
   - Confirm network adapter configuration
   - Check Event Viewer for network events
   - Verify home network prefix setting

3. **Hosts File Not Updating**:
   - Check write permissions on hosts file
   - Look for file locking by other processes (use Option 5)
   - Review logs for specific errors (use Option 3)
   
4. **Log File Issues**:
   - Check permissions on C:\ProgramData\RDGatewayHosts
   - Look for emergency logs in %TEMP% directory
   - Use the log file finder in Option 3

## Security Considerations

- Script runs with SYSTEM privileges for scheduled tasks
- Hosts file modifications are surgical and logged
- Sysinternals tools are downloaded from official Microsoft source
- All actions are logged for audit purposes

## Support

For issues and feature requests, please contact your system administrator or open an issue in the repository.

## License

Internal use only. All rights reserved. 