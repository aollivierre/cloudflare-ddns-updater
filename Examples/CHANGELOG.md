# Changelog
All notable changes to the RD Gateway Hosts Manager will be documented in this file.

## [1.0.0] - 2024-03-28

### Added
- Initial release of RD Gateway Hosts Manager
- Automatic hosts file management based on network location
- Interactive menu system with three options:
  - Run hosts file update now
  - Install scheduled task
  - View log file
- Comprehensive logging system with color-coded output
- Network detection for 198.18.1.x subnet
- DNS resolution testing and verification
- Scheduled task installation with multiple triggers:
  - At user logon
  - Every 15 minutes (regular check)
  - Every minute (for quick network change detection)
  - At startup (1-minute delay)
  - On network profile changes (EventID 10000/10001)
  - On network adapter disconnect (EventID 4202)

### Key Findings and Improvements
- Switched from polling-based network detection to event-based triggers
- Corrected event IDs for network changes:
  - EventID 10000: Network connection event
  - EventID 10001: Network disconnection event
  - EventID 4202: Network adapter disconnection (System log)
- Improved scheduled task creation using XML definition
- Added proper StartBoundary for time triggers
- Implemented SYSTEM context execution for elevated privileges
- Enhanced error handling and logging
- Added DNS cache flushing after hosts file changes

### Technical Decisions
- Used XML-based task creation for better event trigger support
- Implemented both time-based and event-based triggers for reliability
- Set task priority to 7 (above normal)
- Configured 72-hour execution time limit
- Enabled Unified Scheduling Engine
- Set appropriate battery and idle settings

### Fixed
- Resolved issues with script path detection in scheduled tasks
- Fixed network event trigger syntax
- Corrected XML encoding for event subscriptions
- Addressed multiple instance handling
- Improved hosts file entry management to prevent duplicates 