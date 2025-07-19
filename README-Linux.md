# Cloudflare DDNS Updater for Linux

A native Linux service for automatically updating Cloudflare DNS records when your public IP address changes. This is a Python-based alternative to the Windows PowerShell version, designed to run as a systemd service on Linux systems.

## Features

- **Native Linux Service**: Runs as a systemd service with automatic startup
- **Multiple IP Detection Services**: Uses multiple services to detect public IP with fallback
- **Cloudflare API Integration**: Secure integration using API tokens
- **Automatic Updates**: Continuously monitors and updates DNS when IP changes
- **Comprehensive Logging**: Logs to both systemd journal and file
- **Security Hardening**: Runs with minimal privileges and system protections
- **Easy Installation**: Simple installation script handles all setup

## Requirements

- Linux system with systemd (Ubuntu, Debian, CentOS, etc.)
- Python 3.6 or newer
- Root access for installation
- Cloudflare account with:
  - Domain managed by Cloudflare
  - API token with Zone:DNS:Edit and Zone:Zone:Read permissions

## Quick Start

1. **Clone or download this repository**

2. **Edit the configuration file**:
   ```bash
   cp linux-config/config.json.example linux-config/config.json
   nano linux-config/config.json
   ```

3. **Run the installer**:
   ```bash
   sudo ./install.sh
   ```

## Configuration

The configuration file (`/etc/cloudflare-ddns/config.json`) contains:

```json
{
    "Domain": "yourdomain.com",
    "Hostname": "subdomain",
    "ApiToken": "YOUR_CLOUDFLARE_API_TOKEN",
    "ZoneId": "YOUR_CLOUDFLARE_ZONE_ID",
    "TTL": 120,
    "Proxied": false,
    "LogDir": "/var/log/cloudflare-ddns",
    "LastIp": "",
    "LastUpdate": ""
}
```

### Getting Your Cloudflare API Token

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Go to "My Profile" > "API Tokens"
3. Click "Create Token"
4. Use the "Edit zone DNS" template or create custom token with:
   - Permissions: Zone:DNS:Edit and Zone:Zone:Read
   - Zone Resources: Include your specific zone
5. Copy the generated token

### Getting Your Zone ID

1. In Cloudflare Dashboard, select your domain
2. On the right sidebar, find "Zone ID"
3. Copy this value

## Usage

### Service Management

```bash
# Check service status
systemctl status cloudflare-ddns

# Start/stop/restart service
sudo systemctl start cloudflare-ddns
sudo systemctl stop cloudflare-ddns
sudo systemctl restart cloudflare-ddns

# Enable/disable automatic startup
sudo systemctl enable cloudflare-ddns
sudo systemctl disable cloudflare-ddns

# View logs
journalctl -u cloudflare-ddns -f
# or
tail -f /var/log/cloudflare-ddns/cloudflare-ddns.log
```

### Manual Testing

You can test the script manually:

```bash
# Run once and exit
sudo -u cloudflare-ddns python3 /opt/cloudflare-ddns/cloudflare_ddns.py --once

# Run with custom config
python3 cloudflare_ddns.py --config /path/to/config.json --once
```

## File Locations

- **Script**: `/opt/cloudflare-ddns/cloudflare_ddns.py`
- **Config**: `/etc/cloudflare-ddns/config.json`
- **Logs**: `/var/log/cloudflare-ddns/cloudflare-ddns.log`
- **Service**: `/etc/systemd/system/cloudflare-ddns.service`

## Update Interval

By default, the service checks for IP changes every 5 minutes (300 seconds). You can modify this in the service file:

```bash
# Edit the service file
sudo nano /etc/systemd/system/cloudflare-ddns.service

# Change the --interval parameter in ExecStart line
ExecStart=/usr/bin/python3 /opt/cloudflare-ddns/cloudflare_ddns.py --daemon --interval 600

# Reload and restart
sudo systemctl daemon-reload
sudo systemctl restart cloudflare-ddns
```

## Uninstallation

To remove the service completely:

```bash
sudo ./uninstall.sh
```

This will:
- Stop and disable the service
- Remove the service files
- Optionally remove configuration and logs
- Remove the system user

## Troubleshooting

### Service Won't Start

1. Check the logs:
   ```bash
   journalctl -u cloudflare-ddns -n 50
   ```

2. Verify configuration:
   ```bash
   sudo -u cloudflare-ddns python3 /opt/cloudflare-ddns/cloudflare_ddns.py --config /etc/cloudflare-ddns/config.json --once
   ```

3. Check file permissions:
   ```bash
   ls -la /etc/cloudflare-ddns/config.json
   ls -la /var/log/cloudflare-ddns/
   ```

### API Errors

- **401 Unauthorized**: Check your API token is correct and has proper permissions
- **403 Forbidden**: Verify the Zone ID matches your domain
- **404 Not Found**: Ensure the DNS record exists in Cloudflare

### Network Issues

If the service can't detect your public IP:
- Check internet connectivity
- Verify firewall allows outbound HTTPS (port 443)
- Try running the IP detection manually:
  ```bash
  curl https://api.ipify.org
  ```

## Security Considerations

- The service runs as a dedicated system user with minimal privileges
- Configuration file containing API token is protected (mode 600)
- Systemd hardening options are enabled:
  - NoNewPrivileges: Prevents privilege escalation
  - ProtectSystem: Read-only system directories
  - ProtectHome: No access to home directories
  - PrivateTmp: Isolated temporary directory

## Differences from Windows Version

This Linux version:
- Uses Python instead of PowerShell
- Runs as a systemd service instead of Windows Task Scheduler
- Stores logs in `/var/log` instead of `ProgramData`
- Uses JSON config without Windows-specific paths
- No interactive menu (managed via systemctl)
- No GUI components

## Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## License

This project is open source and available under the same license as the original Windows version.