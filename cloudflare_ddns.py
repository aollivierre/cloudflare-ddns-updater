#!/usr/bin/env python3
"""
Cloudflare DDNS Updater for Linux
Updates Cloudflare DNS records with current public IP address
"""

import json
import logging
import os
import sys
import time
import requests
from datetime import datetime
from pathlib import Path


class CloudflareDDNS:
    def __init__(self, config_path="/etc/cloudflare-ddns/config.json"):
        self.config_path = config_path
        self.config = self.load_config()
        self.setup_logging()
        
    def load_config(self):
        """Load configuration from JSON file"""
        try:
            with open(self.config_path, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"Error loading config from {self.config_path}: {e}")
            sys.exit(1)
    
    def setup_logging(self):
        """Setup logging configuration"""
        log_dir = Path(self.config.get('LogDir', '/var/log/cloudflare-ddns'))
        log_dir.mkdir(parents=True, exist_ok=True)
        log_file = log_dir / 'cloudflare-ddns.log'
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def get_public_ip(self):
        """Get current public IP address from multiple services"""
        ip_services = [
            "https://api.ipify.org",
            "https://ifconfig.me/ip",
            "https://icanhazip.com",
            "https://wtfismyip.com/text",
            "https://api.ipify.org?format=text",
            "https://checkip.amazonaws.com"
        ]
        
        for service in ip_services:
            try:
                response = requests.get(service, timeout=5)
                if response.status_code == 200:
                    ip = response.text.strip()
                    # Validate IP format
                    parts = ip.split('.')
                    if len(parts) == 4 and all(0 <= int(part) <= 255 for part in parts):
                        self.logger.info(f"Detected public IP: {ip}")
                        return ip
            except Exception as e:
                self.logger.debug(f"Failed to get IP from {service}: {e}")
                continue
        
        self.logger.error("Failed to get public IP from all services")
        return None
    
    def get_cloudflare_record(self):
        """Get current DNS record from Cloudflare"""
        zone_id = self.config['ZoneId']
        hostname = self.config['Hostname']
        domain = self.config['Domain']
        record_name = f"{hostname}.{domain}"
        
        headers = {
            "Authorization": f"Bearer {self.config['ApiToken']}",
            "Content-Type": "application/json"
        }
        
        url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records"
        params = {"name": record_name, "type": "A"}
        
        try:
            response = requests.get(url, headers=headers, params=params)
            if response.status_code == 200:
                data = response.json()
                if data["success"] and data["result"]:
                    record = data["result"][0]
                    return {
                        "id": record["id"],
                        "content": record["content"],
                        "name": record["name"]
                    }
            else:
                self.logger.error(f"Failed to get DNS record: {response.text}")
        except Exception as e:
            self.logger.error(f"Error getting DNS record: {e}")
        
        return None
    
    def update_dns_record(self, record_id, new_ip):
        """Update DNS record with new IP"""
        zone_id = self.config['ZoneId']
        hostname = self.config['Hostname']
        domain = self.config['Domain']
        record_name = f"{hostname}.{domain}"
        
        headers = {
            "Authorization": f"Bearer {self.config['ApiToken']}",
            "Content-Type": "application/json"
        }
        
        body = {
            "type": "A",
            "name": record_name,
            "content": new_ip,
            "ttl": self.config.get('TTL', 120),
            "proxied": self.config.get('Proxied', False)
        }
        
        url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record_id}"
        
        try:
            response = requests.put(url, headers=headers, json=body)
            if response.status_code == 200:
                data = response.json()
                if data["success"]:
                    self.logger.info(f"Successfully updated DNS record to {new_ip}")
                    return True
                else:
                    self.logger.error(f"Failed to update DNS: {data.get('errors', 'Unknown error')}")
            else:
                self.logger.error(f"Failed to update DNS record: {response.text}")
        except Exception as e:
            self.logger.error(f"Error updating DNS record: {e}")
        
        return False
    
    def save_last_ip(self, ip):
        """Save the last updated IP to config"""
        self.config['LastIp'] = ip
        self.config['LastUpdate'] = datetime.now().isoformat()
        
        try:
            with open(self.config_path, 'w') as f:
                json.dump(self.config, f, indent=4)
        except Exception as e:
            self.logger.error(f"Failed to save config: {e}")
    
    def run_update(self):
        """Main update logic"""
        try:
            # Get current public IP
            current_ip = self.get_public_ip()
            if not current_ip:
                return False
            
            # Get current DNS record
            dns_record = self.get_cloudflare_record()
            if not dns_record:
                self.logger.error("Failed to retrieve DNS record from Cloudflare")
                return False
            
            # Check if update is needed
            if dns_record['content'] == current_ip:
                self.logger.info(f"DNS record already up to date: {current_ip}")
                return True
            
            # Update DNS record
            self.logger.info(f"Updating DNS record from {dns_record['content']} to {current_ip}")
            if self.update_dns_record(dns_record['id'], current_ip):
                self.save_last_ip(current_ip)
                return True
            
            return False
            
        except Exception as e:
            self.logger.error(f"Error during update: {e}")
            return False
    
    def run_daemon(self, interval=300):
        """Run as a daemon, checking every interval seconds"""
        self.logger.info(f"Starting Cloudflare DDNS daemon (interval: {interval}s)")
        
        while True:
            try:
                self.run_update()
            except Exception as e:
                self.logger.error(f"Unexpected error in daemon loop: {e}")
            
            time.sleep(interval)


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Cloudflare DDNS Updater')
    parser.add_argument('-c', '--config', default='/etc/cloudflare-ddns/config.json',
                        help='Path to configuration file')
    parser.add_argument('-d', '--daemon', action='store_true',
                        help='Run as daemon')
    parser.add_argument('-i', '--interval', type=int, default=300,
                        help='Update interval in seconds (default: 300)')
    parser.add_argument('-o', '--once', action='store_true',
                        help='Run once and exit')
    
    args = parser.parse_args()
    
    # Create CloudflareDDNS instance
    ddns = CloudflareDDNS(args.config)
    
    if args.daemon:
        ddns.run_daemon(args.interval)
    else:
        # Run once
        success = ddns.run_update()
        sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()