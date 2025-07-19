# Changelog

All notable changes to the Cloudflare DDNS Updater project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Linux native implementation using Python and systemd
- Comprehensive documentation for both platforms
- Git repository structure with proper branching
- Installation scripts for Linux
- Multiple IP detection services with fallback
- Security hardening for systemd service

### Changed
- Migrated from single Windows solution to multi-platform support
- Improved error handling and logging
- Updated configuration file structure

### Fixed
- API authentication issues with expired tokens
- Line ending compatibility between Windows and Linux

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