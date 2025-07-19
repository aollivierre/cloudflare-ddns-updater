# Changelog

All notable changes to the Cloudflare DDNS Updater project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.0] - 2024-07-19

### Added
- Linux native implementation using Python and systemd
- Comprehensive documentation for both platforms
- Git repository structure with proper branching
- Installation scripts for Linux (install.sh, uninstall.sh)
- Multiple IP detection services with fallback
- Security hardening for systemd service
- Migration guide from Windows to Linux
- Test script for validation
- Proper .gitignore for multi-platform development
- Contributing guidelines

### Changed
- Migrated from single Windows solution to multi-platform support
- Improved error handling and logging across platforms
- Updated configuration file structure for Linux compatibility
- Restructured repository with branch-based platform separation

### Fixed
- API authentication issues with expired tokens
- Line ending compatibility between Windows and Linux
- Ubuntu 24.04 pip installation restrictions

### Removed
- Legacy Docker-based DDNS updater (qdm12)

## [2.0.0] - 2024-01-19

### Added
- PowerShell module structure for better organization
- Interactive menu interface for Windows
- Encrypted credential storage using Windows DPAPI
- Comprehensive logging system
- Multiple scheduled task triggers
- VBS wrapper for invisible operation
- Configuration import/export functionality
- API connection testing feature
- Status dashboard with task information

### Changed
- Moved from single script to modular design
- Configuration stored in external JSON files
- Improved script path detection
- Enhanced error handling

### Security
- API tokens encrypted at rest
- Minimal permission requirements
- Secure configuration storage

## [1.0.0] - 2023-11-01

### Added
- Initial PowerShell implementation
- Basic Cloudflare API integration
- Windows Task Scheduler support
- Simple logging functionality
- Configuration through script variables

### Known Issues
- Manual configuration required
- Limited error handling
- No encryption for credentials

---

## Version History Summary

- **v2.0.0** - Major rewrite with modular design and enhanced features
- **v1.0.0** - Initial release with basic functionality