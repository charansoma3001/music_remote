"""
Trusted device management for the server.
Stores and validates device fingerprints.
"""

import os
import json
import hashlib
from datetime import datetime


class TrustedDeviceManager:
    """Manage trusted devices that can auto-connect."""
    
    def __init__(self, config_dir):
        self.config_dir = config_dir
        self.devices_file = os.path.join(config_dir, 'trusted_devices.json')
        self.devices = self._load_devices()
    
    def _load_devices(self):
        """Load trusted devices from file."""
        if os.path.exists(self.devices_file):
            try:
                with open(self.devices_file, 'r') as f:
                    return json.load(f)
            except:
                return {}
        return {}
    
    def _save_devices(self):
        """Save trusted devices to file."""
        os.makedirs(self.config_dir, exist_ok=True)
        with open(self.devices_file, 'w') as f:
            json.dump(self.devices, f, indent=2)
    
    def add_device(self, device_fingerprint, device_name=None):
        """
        Add a device to trusted list.
        
        Args:
            device_fingerprint (str): Unique device identifier
            device_name (str): Optional friendly name for the device
        """
        self.devices[device_fingerprint] = {
            'name': device_name or 'Unknown Device',
            'added_at': datetime.now().isoformat(),
            'last_seen': datetime.now().isoformat()
        }
        self._save_devices()
    
    def is_trusted(self, device_fingerprint):
        """Check if a device is trusted."""
        if device_fingerprint in self.devices:
            # Update last seen
            self.devices[device_fingerprint]['last_seen'] = datetime.now().isoformat()
            self._save_devices()
            return True
        return False
    
    def remove_device(self, device_fingerprint):
        """Remove a device from trusted list."""
        if device_fingerprint in self.devices:
            del self.devices[device_fingerprint]
            self._save_devices()
            return True
        return False
    
    def get_all_devices(self):
        """Get all trusted devices."""
        return self.devices
    
    def get_device_hash(self, device_info):
        """
        Generate a secure hash from device information.
        
        Args:
            device_info (dict): Device information to hash
            
        Returns:
            str: SHA256 hash of device info
        """
        # Sort keys for consistent hashing
        info_str = json.dumps(device_info, sort_keys=True)
        return hashlib.sha256(info_str.encode()).hexdigest()
