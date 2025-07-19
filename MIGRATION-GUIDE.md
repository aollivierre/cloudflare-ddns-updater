# Windows to Linux Migration Guide

This guide helps you migrate from the Windows PowerShell version to the native Linux version of Cloudflare DDNS Updater.

## Quick Migration Steps

1. **Transfer your configuration values** from the Windows config to Linux:
   - Open your Windows config: `C:\ProgramData\CloudflareDDNS\CloudflareDDNS-Config.json`
   - Copy these values:
     - Domain
     - Hostname  
     - ApiToken
     - ZoneId
     - TTL

2. **On your Linux server**, edit the config file:
   ```bash
   nano linux-config/config.json
   ```
   
   Enter your values from Windows:
   ```json
   {
       "Domain": "cloudcommand.org",
       "Hostname": "rdgateway02",
       "ApiToken": "YOUR_API_TOKEN",
       "ZoneId": "YOUR_ZONE_ID",
       "TTL": 120,
       "Proxied": false,
       "LogDir": "/var/log/cloudflare-ddns",
       "LastIp": "",
       "LastUpdate": ""
   }
   ```

3. **Install the service**:
   ```bash
   sudo ./install.sh
   ```

## Key Differences

| Feature | Windows Version | Linux Version |
|---------|----------------|---------------|
| Language | PowerShell | Python 3 |
| Service Type | Windows Task Scheduler | systemd service |
| Config Location | `C:\ProgramData\CloudflareDDNS\` | `/etc/cloudflare-ddns/` |
| Log Location | `C:\ProgramData\CloudflareDDNS\*.log` | `/var/log/cloudflare-ddns/` |
| Management | Interactive menu | systemctl commands |
| User Interface | Console menu | Command line only |
| Installation | PowerShell script | Bash script |

## Feature Comparison

### Windows Features Not in Linux Version
- Interactive menu interface
- Configuration encryption with DPAPI
- VBS wrapper for invisible mode
- Task Scheduler integration GUI
- Import/Export configuration wizard

### Linux Features Not in Windows Version
- Native systemd integration
- Runs as dedicated system user
- Security hardening (ProtectSystem, etc.)
- Standard Linux logging (journald + file)
- Simple command-line interface

## Common Tasks Translation

### Check Status
**Windows:**
```powershell
.\Update-CloudflareDDNS.ps1
# Then select option 11
```

**Linux:**
```bash
systemctl status cloudflare-ddns
```

### View Logs
**Windows:**
```powershell
.\Update-CloudflareDDNS.ps1
# Then select option 4
```

**Linux:**
```bash
journalctl -u cloudflare-ddns -f
# or
tail -f /var/log/cloudflare-ddns/cloudflare-ddns.log
```

### Update Now
**Windows:**
```powershell
.\Update-CloudflareDDNS.ps1
# Then select option 1
```

**Linux:**
```bash
sudo -u cloudflare-ddns python3 /opt/cloudflare-ddns/cloudflare_ddns.py --once
```

### Edit Configuration
**Windows:**
```powershell
.\Update-CloudflareDDNS.ps1
# Then select option 6
```

**Linux:**
```bash
sudo nano /etc/cloudflare-ddns/config.json
sudo systemctl restart cloudflare-ddns
```

### Start/Stop Service
**Windows:**
```powershell
.\Update-CloudflareDDNS.ps1
# Then select option 12 to enable/disable
```

**Linux:**
```bash
sudo systemctl stop cloudflare-ddns
sudo systemctl start cloudflare-ddns
```

## Troubleshooting Migration Issues

### API Token Issues
If you get authentication errors after migration:
1. Ensure you copied the API token exactly (no extra spaces)
2. Verify the token hasn't expired in Cloudflare
3. Check the token has proper permissions (Zone:DNS:Edit, Zone:Zone:Read)

### Permission Errors
If you see permission denied errors:
```bash
sudo chown cloudflare-ddns:cloudflare-ddns /etc/cloudflare-ddns/config.json
sudo chmod 600 /etc/cloudflare-ddns/config.json
```

### Service Won't Start
Check the service logs:
```bash
journalctl -u cloudflare-ddns -n 50 --no-pager
```

## Advantages of Linux Version

1. **Lower Resource Usage**: Python script uses less memory than PowerShell
2. **Better Integration**: Native systemd integration with Linux systems
3. **Security**: Runs with minimal privileges as dedicated user
4. **Simplicity**: No GUI overhead, pure command-line operation
5. **Reliability**: systemd automatically restarts on failure
6. **Standard Logging**: Integrates with system logging infrastructure

## Running Both Versions

You can run both Windows and Linux versions simultaneously if needed:
- They can update the same DNS record
- The last update wins
- Useful during migration period
- No conflicts as long as they check the same record

## Need Help?

- Check logs first: `journalctl -u cloudflare-ddns -f`
- Verify configuration: `cat /etc/cloudflare-ddns/config.json`
- Test manually: `sudo -u cloudflare-ddns python3 /opt/cloudflare-ddns/cloudflare_ddns.py --once`
- Review this guide and README-Linux.md