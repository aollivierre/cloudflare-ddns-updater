#!/bin/bash

# Cloudflare DDNS Uninstaller Script

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

echo -e "${YELLOW}=== Cloudflare DDNS Uninstaller ===${NC}"
echo

read -p "Are you sure you want to uninstall Cloudflare DDNS? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Stop and disable service
if systemctl is-active --quiet cloudflare-ddns; then
    echo -e "${YELLOW}Stopping service...${NC}"
    systemctl stop cloudflare-ddns
fi

if systemctl is-enabled --quiet cloudflare-ddns 2>/dev/null; then
    echo -e "${YELLOW}Disabling service...${NC}"
    systemctl disable cloudflare-ddns
fi

# Remove service file
if [ -f "$SERVICE_FILE" ]; then
    echo -e "${YELLOW}Removing service file...${NC}"
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload
fi

# Remove installation directory
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Removing installation directory...${NC}"
    rm -rf "$INSTALL_DIR"
fi

# Ask about config and logs
read -p "Do you want to remove configuration files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing configuration...${NC}"
    rm -rf "$CONFIG_DIR"
fi

read -p "Do you want to remove log files? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Removing logs...${NC}"
    rm -rf "$LOG_DIR"
fi

# Remove user
if id -u cloudflare-ddns > /dev/null 2>&1; then
    echo -e "${YELLOW}Removing system user...${NC}"
    userdel cloudflare-ddns
fi

echo
echo -e "${GREEN}✓ Cloudflare DDNS has been uninstalled.${NC}"