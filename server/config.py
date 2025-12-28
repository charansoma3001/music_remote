"""
Configuration and token management for the Apple Music remote server.
"""

import os
import secrets
from pathlib import Path


class Config:
    """Configuration management for the server."""
    
    # Configuration directory
    CONFIG_DIR = Path.home() / '.music_remote'
    TOKEN_FILE = CONFIG_DIR / 'auth_token.txt'
    
    def __init__(self):
        self.host = os.getenv('SERVER_HOST', '0.0.0.0')
        self.port = int(os.getenv('SERVER_PORT', 5000))
        self.auth_token = self._load_or_generate_token()
        self.config_dir = str(self.CONFIG_DIR)  # String version for trusted devices
        
    def _load_or_generate_token(self):
        """Load existing token or create a new one."""
        # Create config directory if it doesn't exist
        self.CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        
        # Try to load existing token
        if self.TOKEN_FILE.exists():
            with open(self.TOKEN_FILE, 'r') as f:
                token = f.read().strip()
                if token:
                    return token
        
        # Generate new token if none exists
        token = secrets.token_urlsafe(32)
        
        # Save token to file
        with open(self.TOKEN_FILE, 'w') as f:
            f.write(token)
        
        return token
    
    def display_token(self):
        """Display the authentication token prominently."""
        print("\n" + "="*60)
        print("🔐 AUTHENTICATION TOKEN")
        print("="*60)
        print(f"\nYour token: {self.auth_token}")
        print(f"\nToken saved in: {self.TOKEN_FILE}")
        print("\n⚠️  Keep this token secure! It grants full access to your")
        print("   Apple Music controls.")
        print("="*60 + "\n")
        
    def display_qr_code(self, server_url):
        """Display a QR code for easy mobile setup."""
        try:
            import qrcode
            
            # Create connection data
            connection_data = f"{server_url}|{self.auth_token}"
            
            # Generate QR code
            qr = qrcode.QRCode(
                version=1,
                error_correction=qrcode.constants.ERROR_CORRECT_L,
                box_size=10,
                border=4,
            )
            qr.add_data(connection_data)
            qr.make(fit=True)
            
            # Print QR code to terminal
            print("\n" + "="*60)
            print("📱 SCAN THIS QR CODE WITH YOUR MOBILE APP")
            print("="*60)
            qr.print_ascii(invert=True)
            print("="*60)
            print(f"Server URL: {server_url}")
            print(f"Token: {self.auth_token}")
            print("="*60 + "\n")
        except ImportError:
            print("\n⚠️  Install qrcode to see QR code: pip install qrcode[pil]\n")
