# Overview  
The CloudflareDDNS PowerShell module provides a robust, user-friendly solution for automatically updating Cloudflare DNS records when your public IP address changes. This solves the problem faced by home server operators, remote workers, and self-hosters who need reliable DNS resolution without paying for dedicated DDNS services. By leveraging Cloudflare's global DNS infrastructure and API, this module offers a free alternative with enhanced reliability, security features, and a convenient management interface.

# Core Features  

## Terminal User Interface
- **What it does**: Provides an interactive menu-based interface for managing all DDNS functionality
- **Why it's important**: Makes the tool accessible to users with limited PowerShell experience and simplifies common operations
- **How it works**: Presents numbered options with descriptions, handles user input, and executes appropriate functions

## Automatic IP Detection & DNS Updates
- **What it does**: Detects public IP changes and updates Cloudflare DNS records automatically
- **Why it's important**: Core functionality that ensures DNS records always reflect the current IP address
- **How it works**: Queries reliable IP detection services, compares with existing DNS records, and updates only when needed to minimize API calls

## Scheduled Task Management
- **What it does**: Creates, configures, enables/disables, and removes Windows scheduled tasks
- **Why it's important**: Ensures the DDNS client runs automatically without user intervention
- **How it works**: Configures multiple trigger types (startup, logon, network changes, intervals) for maximum reliability

## Secure Configuration Storage
- **What it does**: Securely stores API tokens and other sensitive configuration data
- **Why it's important**: Protects Cloudflare credentials from unauthorized access
- **How it works**: Uses Windows DPAPI for encryption, separates sensitive and non-sensitive configuration data

## Comprehensive Logging
- **What it does**: Records all operations, errors, and status changes
- **Why it's important**: Essential for troubleshooting and monitoring
- **How it works**: Maintains separate logs for setup/configuration and task execution, implements log rotation

## Status Dashboard
- **What it does**: Displays current synchronization status and task information
- **Why it's important**: Provides immediate visibility into the system's operational state
- **How it works**: Queries Cloudflare API, local configuration, and task scheduler to compile status information

## API Connection Testing
- **What it does**: Verifies Cloudflare credentials and permissions without making changes
- **Why it's important**: Helps diagnose configuration issues before attempting updates
- **How it works**: Performs read-only API operations to validate token, zone ID, and record access

# User Experience  

## User Personas

### Home Server Administrator
- Technical skill: Moderate
- Primary goals: Maintain reliable remote access to home services
- Key needs: Set-and-forget reliability, simple troubleshooting

### IT Professional
- Technical skill: High
- Primary goals: Maintain multiple DDNS configurations efficiently
- Key needs: Configuration portability, scriptability, detailed logs

### Non-Technical Self-Hoster
- Technical skill: Low
- Primary goals: Basic DDNS functionality without complexity
- Key needs: Simple interface, clear status indicators, minimal configuration

## Key User Flows

### First-Time Setup
1. User imports the module
2. User runs the interactive menu
3. User configures Cloudflare settings (API token, zone, domain)
4. User installs the scheduled task
5. User verifies initial update was successful

### Routine Verification
1. User imports the module
2. User checks status dashboard
3. User views logs if any issues are detected

### Configuration Change
1. User imports the module
2. User accesses configuration editor
3. User modifies settings
4. User tests connection to verify changes

## UI/UX Considerations
- Terminal interface must be clean and intuitive with clear numbering
- Status information should use consistent formatting and clear success/failure indicators
- Operation feedback must be immediate and descriptive
- All user prompts should have sensible defaults when possible
- Help information should be context-sensitive and accessible

# Technical Architecture  

## System Components

### Core Module Components
- **Module Manifest** (.psd1): Defines metadata, exports functions
- **Module Script** (.psm1): Handles initialization, imports functions
- **Public Functions**: Exports cmdlets accessible to users
- **Private Functions**: Internal utilities not directly exposed

### Function Categories
- **Configuration Management**: Handles settings storage/retrieval
- **API Interaction**: Manages Cloudflare API communication
- **Task Management**: Interfaces with Windows Task Scheduler
- **User Interface**: Handles menu display and input
- **Logging**: Manages diagnostic information
- **Security**: Handles encryption/decryption

### File Structure
```
CloudflareDDNS/
├── CloudflareDDNS.psd1          # Module manifest
├── CloudflareDDNS.psm1          # Module loader
├── Public/                      # Exported functions
│   ├── Update-CloudflareDNSRecord.ps1
│   ├── Show-CloudflareDDNSMenu.ps1
│   └── ... (additional public functions)
├── Private/                     # Internal functions
│   ├── Get-PublicIPAddress.ps1
│   ├── Invoke-CloudflareAPI.ps1
│   └── ... (additional private functions)
└── Config/                      # Configuration templates
    └── default-config.json
```

## Data Models

### Configuration Data Structure
```json
{
  "ZoneId": "zone-identifier",
  "Domain": "example.com",
  "HostName": "subdomain",
  "RecordType": "A",
  "TTL": 120,
  "Proxied": false,
  "LogDir": "C:\\ProgramData\\CloudflareDDNS",
  "ConfigDir": "C:\\ProgramData\\CloudflareDDNS",
  "EncryptionEnabled": true
}
```

### Secure Configuration Structure
```json
{
  "ApiToken": "encrypted-api-token-data"
}
```

### Log Entry Structure
```
[2023-07-05 15:30:45] [INFO] Current public IP: 203.0.113.10
[2023-07-05 15:30:46] [INFO] Cloudflare DNS record: 203.0.113.10
[2023-07-05 15:30:46] [INFO] DNS record is up to date
```

## APIs and Integrations

### Cloudflare API Integration
- Uses REST API with Bearer token authentication
- Requires Zone:DNS:Edit and Zone:Zone:Read permissions
- Key endpoints:
  - GET zones/{zone_id}/dns_records (retrieve records)
  - PUT zones/{zone_id}/dns_records/{id} (update record)
  - GET zones/{zone_id} (verify zone access)

### IP Detection Services
- Primary: api.ipify.org
- Fallbacks: ifconfig.me, ipinfo.io, icanhazip.com
- All accessed via HTTPS GET requests

### Windows Task Scheduler Integration
- Uses Microsoft.Win32.TaskScheduler COM objects
- Creates tasks with multiple triggers
- Configures for running with highest privileges

## Infrastructure Requirements

### Client Requirements
- Windows 10/11 or Windows Server 2016/2019/2022
- PowerShell 5.1 or newer
- Internet connectivity
- Administrator rights (for scheduled task creation)

### External Dependencies
- Cloudflare account with domain
- API token with appropriate permissions
- Public IP detection services accessibility

# Development Roadmap  

## Phase 1: Core Module Foundation
- Establish proper module structure (Public/Private folders, manifest)
- Implement configuration management system
- Develop IP detection with fallback mechanisms
- Create basic Cloudflare API integration functions
- Implement logging system with rotation
- Build simple configuration encryption/decryption

## Phase 2: Basic Functionality
- Implement DNS record retrieval and comparison 
- Develop DNS record update functionality
- Create connection testing capabilities
- Build status checking functionality
- Implement configuration editor
- Develop log viewing and management functions

## Phase 3: Task Management & UI
- Create Windows scheduled task management functions
- Implement terminal menu interface
- Develop task status inspection and management
- Create comprehensive status dashboard
- Implement error handling with user-friendly messages
- Build help system and documentation

## Phase 4: Advanced Features
- Implement configuration import/export
- Develop multiple record management
- Create configuration encryption toggles
- Build multiple domain/zone support
- Implement task trigger customization
- Develop silent operation mode

## Phase 5: Refinement
- Comprehensive error handling for edge cases
- Performance optimization for slower systems
- Backwards compatibility with older PowerShell versions
- Optimized logging for long-term use
- Enhanced feedback for non-technical users

# Logical Dependency Chain

## Foundation Components (Build First)
1. Module structure and initialization
2. Configuration management system
3. Logging system
4. Basic Cloudflare API functions
5. IP detection with fallbacks

## Core Functionality Chain
1. DNS record retrieval -> DNS comparison -> DNS updates
2. Configuration encryption -> Secure storage -> Configuration editing
3. Connection testing -> Status reporting -> Error handling

## User Interface Chain
1. Simple command functions -> Basic menu interface -> Enhanced interactive menu
2. Task creation -> Task status monitoring -> Task modification
3. Basic status output -> Formatted status display -> Comprehensive dashboard

## Critical Path to MVP
1. Module skeleton with proper structure
2. Configuration system that securely stores API credentials
3. IP detection and Cloudflare record comparison
4. DNS record update functionality
5. Simple scheduled task creation
6. Basic menu interface

# Risks and Mitigations  

## Technical Challenges

### PowerShell Version Compatibility
- **Risk**: Functions may not work on older PowerShell versions
- **Mitigation**: Test on PowerShell 5.1, avoid newer language features, include version checks

### Secure Credential Storage
- **Risk**: API tokens could be exposed if encryption fails
- **Mitigation**: Implement multiple layers of protection, clear memory after use, validate encryption success

### IP Detection Reliability
- **Risk**: IP detection services may be unavailable
- **Mitigation**: Implement multiple fallback services, retry logic, and circuit breaker pattern

### Task Scheduler Limitations
- **Risk**: Scheduled tasks may not trigger reliably in all environments
- **Mitigation**: Use multiple trigger types, implement self-healing mechanisms, add status verification

## MVP Priorities

### Core Update Functionality
- **Risk**: Focusing too much on UI before core functions work
- **Mitigation**: Establish working DNS update pipeline first, then build management features

### Module Organization
- **Risk**: Poor initial architecture leads to refactoring challenges
- **Mitigation**: Establish clean separation of concerns from the start, use consistent patterns

### Error Handling
- **Risk**: Edge cases and error states not properly managed
- **Mitigation**: Implement comprehensive try/catch blocks, validate all inputs, provide clear error messages

## Resource Constraints

### Testing Environment Diversity
- **Risk**: Limited testing across different Windows versions
- **Mitigation**: Use compatibility functions, avoid OS-specific features where possible

### Performance on Low-Resource Systems
- **Risk**: Script could be resource-intensive on older systems
- **Mitigation**: Optimize code paths, limit concurrent operations, implement throttling

# Appendix  

## Cloudflare API Information

### API Endpoints
- List DNS Records: `GET zones/{zone_id}/dns_records`
- Get DNS Record Details: `GET zones/{zone_id}/dns_records/{id}`
- Update DNS Record: `PUT zones/{zone_id}/dns_records/{id}`
- Create DNS Record: `POST zones/{zone_id}/dns_records`

### API Token Permissions
Required permissions for API tokens:
- Zone - DNS - Edit
- Zone - Zone - Read

### Rate Limits
- 1,200 requests per 5 minutes

## PowerShell Best Practices

### Module Structure
- Use approved verbs for function names
- Implement proper pipeline support
- Include comment-based help
- Support -WhatIf and -Confirm where appropriate

### Error Handling
- Use try/catch blocks for recoverable errors
- Implement proper error records with categorization
- Maintain call stack information for troubleshooting

### Security Considerations
- Never store credentials in plain text
- Use SecureString for credentials in memory
- Clear sensitive information from memory when no longer needed
- Always validate user input

## Windows Task Scheduler Details

### Task Trigger Types
- **Boot**: Triggers after system startup (with delay)
- **Logon**: Triggers when user logs on
- **Schedule**: Triggers at specific times/intervals
- **Event**: Triggers when specific Windows events occur

### Suggested Task Configuration
- Run with highest privileges
- Do not store password
- Hidden execution
- Allow task to be run on demand
- Multiple retry attempts 