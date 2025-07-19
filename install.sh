#!/bin/bash

# Cloudflare DDNS Installation Script for Linux
# This script installs the Cloudflare DDNS updater as a systemd service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Installation directories
INSTALL_DIR="/opt/cloudflare-ddns"
CONFIG_DIR="/etc/cloudflare-ddns"
LOG_DIR="/var/log/cloudflare-ddns"
SERVICE_FILE="/etc/systemd/system/cloudflare-ddns.service"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

echo -e "${GREEN}=== Cloudflare DDNS Installer ===${NC}"
echo

# Check for Python 3
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Python 3 is required but not installed.${NC}"
    echo "Please install Python 3 and try again."
    exit 1
fi

# Check for required Python packages
echo -e "${YELLOW}Checking Python dependencies...${NC}"
if ! python3 -c "import requests" 2>/dev/null; then
    echo -e "${YELLOW}Installing python3-requests...${NC}"
    apt-get install -y python3-requests || {
        echo -e "${RED}Failed to install Python dependencies${NC}"
        echo "Please install manually: apt-get install python3-requests"
        exit 1
    }
else
    echo -e "${GREEN}Python dependencies already installed${NC}"
fi

# Create directories
echo -e "${YELLOW}Creating directories...${NC}"
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"

# Copy files
echo -e "${YELLOW}Copying files...${NC}"
cp cloudflare_ddns.py "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/cloudflare_ddns.py"

# Handle configuration
if [ -f "$CONFIG_DIR/config.json" ]; then
    echo -e "${YELLOW}Configuration file already exists at $CONFIG_DIR/config.json${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "linux-config/config.json" ]; then
            cp linux-config/config.json "$CONFIG_DIR/"
        else
            cp linux-config/config.json.example "$CONFIG_DIR/config.json"
            echo -e "${YELLOW}Please edit $CONFIG_DIR/config.json with your Cloudflare credentials${NC}"
        fi
    fi
else
    if [ -f "linux-config/config.json" ]; then
        cp linux-config/config.json "$CONFIG_DIR/"
    else
        cp linux-config/config.json.example "$CONFIG_DIR/config.json"
        echo -e "${YELLOW}Please edit $CONFIG_DIR/config.json with your Cloudflare credentials${NC}"
    fi
fi

# Create system user for the service
echo -e "${YELLOW}Creating system user...${NC}"
if ! id -u cloudflare-ddns > /dev/null 2>&1; then
    useradd --system --no-create-home --shell /bin/false cloudflare-ddns
fi

# Set permissions
chown -R cloudflare-ddns:cloudflare-ddns "$LOG_DIR"
chown -R cloudflare-ddns:cloudflare-ddns "$CONFIG_DIR"
chmod 600 "$CONFIG_DIR/config.json"  # Protect config file with API token

# Install systemd service
echo -e "${YELLOW}Installing systemd service...${NC}"
cp cloudflare-ddns.service "$SERVICE_FILE"

# Reload systemd
systemctl daemon-reload

# Enable and start service
echo -e "${YELLOW}Enabling and starting service...${NC}"
systemctl enable cloudflare-ddns
systemctl start cloudflare-ddns

# Check service status
sleep 2
if systemctl is-active --quiet cloudflare-ddns; then
    echo -e "${GREEN}✓ Service is running successfully!${NC}"
else
    echo -e "${RED}✗ Service failed to start. Check logs with: journalctl -u cloudflare-ddns${NC}"
    exit 1
fi

echo
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo
echo "Service Management Commands:"
echo "  - Check status: systemctl status cloudflare-ddns"
echo "  - View logs: journalctl -u cloudflare-ddns -f"
echo "  - Restart service: systemctl restart cloudflare-ddns"
echo "  - Stop service: systemctl stop cloudflare-ddns"
echo
echo "Configuration:"
echo "  - Edit config: nano $CONFIG_DIR/config.json"
echo "  - After editing config, restart service: systemctl restart cloudflare-ddns"
echo
echo "Log files are stored in: $LOG_DIR"
echo

# Test the configuration
echo -e "${YELLOW}Testing configuration...${NC}"
if python3 "$INSTALL_DIR/cloudflare_ddns.py" --config "$CONFIG_DIR/config.json" --once; then
    echo -e "${GREEN}✓ Configuration test successful!${NC}"
else
    echo -e "${RED}✗ Configuration test failed. Please check your settings.${NC}"
fi