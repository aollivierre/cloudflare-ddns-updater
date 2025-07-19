# Cloudflare DDNS Updater

A robust Dynamic DNS (DDNS) updater for Cloudflare that automatically updates your DNS records when your public IP address changes. Available in both Windows (PowerShell) and Linux (Python) implementations.

## 🌟 Features

- **Automatic IP Detection**: Monitors your public IP and updates DNS records when it changes
- **Multi-Platform Support**: Native implementations for both Windows and Linux
- **Reliable Updates**: Multiple IP detection services with automatic fallback
- **Secure**: Encrypted credential storage and minimal permission requirements
- **24/7 Operation**: Runs continuously as a background service
- **Comprehensive Logging**: Detailed logs for troubleshooting and monitoring
- **Easy Configuration**: Simple JSON-based configuration

## 🚀 Quick Start

### Windows (PowerShell)

```powershell
# Run with administrator privileges
.\Update-CloudflareDDNS.ps1

# Install as scheduled task
.\Update-CloudflareDDNS.ps1 -InstallTask
```

### Linux (Python)

```bash
# Install and start service
sudo ./install.sh

# Check status
systemctl status cloudflare-ddns
```

## 📋 Requirements

### Common Requirements
- Cloudflare account with a domain
- API token with DNS edit permissions
- Internet connection

### Windows Specific
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1 or newer
- Administrator privileges

### Linux Specific
- Linux with systemd (Ubuntu, Debian, CentOS, etc.)
- Python 3.6+
- sudo access

## 🛠️ Installation

### Windows Installation

1. Download the PowerShell scripts to a permanent location
2. Run PowerShell as Administrator
3. Navigate to the script directory
4. Run: `.\Update-CloudflareDDNS.ps1`
5. Follow the interactive menu to configure and install

### Linux Installation

1. Clone the repository or download the files
2. Edit `linux-config/config.json` with your details
3. Run: `sudo ./install.sh`
4. Service starts automatically

## ⚙️ Configuration

### Cloudflare API Token

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Go to My Profile → API Tokens
3. Click "Create Token"
4. Use "Edit zone DNS" template with:
   - Permissions: Zone:DNS:Edit, Zone:Zone:Read
   - Zone Resources: Your specific domain

### Configuration File

```json
{
    "Domain": "yourdomain.com",
    "Hostname": "subdomain",
    "ApiToken": "YOUR_API_TOKEN",
    "ZoneId": "YOUR_ZONE_ID",
    "TTL": 120,
    "Proxied": false
}
```

## 🌳 Branches

- `main`: Windows PowerShell implementation
- `linux-native`: Linux Python implementation

## 📁 Project Structure

```
cloudflare-ddns/
├── Windows (main branch)
│   ├── Update-CloudflareDDNS.ps1
│   ├── DDNS/
│   │   └── CloudflareDDNS/
│   │       ├── CloudflareDDNS.psd1
│   │       ├── CloudflareDDNS.psm1
│   │       ├── Public/
│   │       └── Private/
│   └── config/
│
└── Linux (linux-native branch)
    ├── cloudflare_ddns.py
    ├── cloudflare-ddns.service
    ├── install.sh
    ├── uninstall.sh
    └── linux-config/
```

## 🔧 Usage

### Windows Commands

```powershell
# Interactive menu
.\Update-CloudflareDDNS.ps1

# Silent update
.\Update-CloudflareDDNS.ps1 -Silent

# View logs
.\Update-CloudflareDDNS.ps1 -ShowLog
```

### Linux Commands

```bash
# Service management
systemctl start cloudflare-ddns
systemctl stop cloudflare-ddns
systemctl restart cloudflare-ddns
systemctl status cloudflare-ddns

# View logs
journalctl -u cloudflare-ddns -f

# Manual test
python3 cloudflare_ddns.py --config /etc/cloudflare-ddns/config.json --once
```

## 📊 Monitoring

### Windows
- Logs: `C:\ProgramData\CloudflareDDNS\*.log`
- Task Scheduler for status

### Linux
- Logs: `/var/log/cloudflare-ddns/cloudflare-ddns.log`
- systemd journal: `journalctl -u cloudflare-ddns`

## 🐛 Troubleshooting

### Common Issues

1. **Authentication Errors**
   - Verify API token is valid
   - Check token permissions
   - Ensure Zone ID is correct

2. **IP Detection Failures**
   - Check internet connectivity
   - Verify firewall allows HTTPS outbound
   - Try different IP detection services

3. **Service Won't Start**
   - Check logs for specific errors
   - Verify configuration file syntax
   - Ensure proper permissions

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Cloudflare for their excellent API
- Community contributors and testers
- IP detection services (ipify, ifconfig.me, etc.)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/aollivierre/cloudflare-ddns-updater/issues)
- **Discussions**: [GitHub Discussions](https://github.com/aollivierre/cloudflare-ddns-updater/discussions)
- **Wiki**: [Project Wiki](https://github.com/aollivierre/cloudflare-ddns-updater/wiki)

## 🔗 Links

- [Cloudflare API Documentation](https://developers.cloudflare.com/api/)
- [PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/)
- [Python Documentation](https://docs.python.org/3/)
- [systemd Documentation](https://www.freedesktop.org/software/systemd/man/)

---

Made with ❤️ for the self-hosting community