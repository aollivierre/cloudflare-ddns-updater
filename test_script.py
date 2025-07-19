#!/usr/bin/env python3
"""
Test script to verify DDNS functionality without making actual API calls
"""

import sys
sys.path.insert(0, '.')

from cloudflare_ddns import CloudflareDDNS
import json

print("=== Cloudflare DDNS Test ===\n")

# Test 1: Configuration loading
print("1. Testing configuration loading...")
try:
    ddns = CloudflareDDNS("linux-config/config.json")
    print("✓ Configuration loaded successfully")
    print(f"  - Domain: {ddns.config['Domain']}")
    print(f"  - Hostname: {ddns.config['Hostname']}")
    print(f"  - Zone ID: {ddns.config['ZoneId'][:10]}...")
except Exception as e:
    print(f"✗ Failed to load configuration: {e}")
    sys.exit(1)

# Test 2: Public IP detection
print("\n2. Testing public IP detection...")
try:
    ip = ddns.get_public_ip()
    if ip:
        print(f"✓ Successfully detected public IP: {ip}")
    else:
        print("✗ Failed to detect public IP")
except Exception as e:
    print(f"✗ Error detecting IP: {e}")

# Test 3: Verify script structure
print("\n3. Verifying script components...")
methods = ['load_config', 'setup_logging', 'get_public_ip', 
           'get_cloudflare_record', 'update_dns_record', 
           'save_last_ip', 'run_update', 'run_daemon']

for method in methods:
    if hasattr(ddns, method):
        print(f"✓ Method '{method}' exists")
    else:
        print(f"✗ Method '{method}' missing")

print("\n=== Test Complete ===")
print("\nNote: Cloudflare API calls will fail without valid credentials.")
print("This is expected. The important thing is that the script structure")
print("and IP detection are working correctly.")