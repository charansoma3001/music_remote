"""
Background monitoring service for Apple Music state changes.
Detects changes and triggers WebSocket broadcasts.
"""

import time
import threading
from typing import Optional, Dict, Any
import applescript_commands as asc


class MusicMonitor:
    """Monitors Apple Music for state changes and triggers callbacks."""
    
    def __init__(self, on_change_callback):
        """
        Initialize the monitor.
        
        Args:
            on_change_callback: Function to call when state changes.
                                Receives dict with changed fields.
        """
        self.on_change_callback = on_change_callback
        self.running = False
        self.thread: Optional[threading.Thread] = None
        
        # Cache previous state
        self.last_state: Dict[str, Any] = {}
        
    def start(self):
        """Start monitoring in background thread."""
        if self.running:
            return
            
        self.running = True
        self.thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.thread.start()
        print("🎵 Music monitor started")
        
    def stop(self):
        """Stop monitoring."""
        self.running = False
        if self.thread:
            self.thread.join(timeout=2)
        print("🎵 Music monitor stopped")
        
    def _monitor_loop(self):
        """Main monitoring loop - runs in background thread."""
        while self.running:
            try:
                current_state = self._get_current_state()
                changes = self._detect_changes(current_state)
                
                if changes:
                    # Broadcast changes to all connected clients
                    self.on_change_callback(changes)
                
                # Always update last_state, even for position-only changes
                self.last_state = current_state
                    
            except Exception as e:
                print(f"Monitor error: {e}")
                
            # Poll every 500ms (only server-side, very efficient)
            time.sleep(0.5)
            
    def _get_current_state(self) -> Dict[str, Any]:
        """Get current Music.app state."""
        try:
            track_info = asc.get_current_track()
            # Get playback state  
            state = 'stopped'
            try:
                state_result = asc.execute_applescript('''
                    tell application "Music"
                        return player state as string
                    end tell
                ''')
                state = state_result.strip().lower() if state_result else 'stopped'
            except:
                pass
            
            return {
                'track_name': track_info.get('name'),
                'track_artist': track_info.get('artist'),
                'track_album': track_info.get('album'),
                'position': track_info.get('position', 0),
                'duration': track_info.get('duration', 0),
                'state': state,
                'volume': 50,  # We'll get this from status endpoint if needed
            }
        except Exception:
            return {}
            
    def _detect_changes(self, current_state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Compare current state with last state and return changes.
        
        Returns:
            Dict with only the changed fields, or None if no significant changes.
        """
        if not self.last_state:
            # First run - return full state
            return {'type': 'full_update', **current_state}
            
        changes = {}
        
        # Check for track change
        if (current_state.get('track_name') != self.last_state.get('track_name') or
            current_state.get('track_artist') != self.last_state.get('track_artist')):
            changes['type'] = 'track_changed'
            changes['track'] = {
                'name': current_state.get('track_name'),
                'artist': current_state.get('track_artist'),
                'album': current_state.get('track_album'),
                'position': current_state.get('position'),
                'duration': current_state.get('duration'),
            }
            
        # Check for playback state change
        if current_state.get('state') != self.last_state.get('state'):
            if not changes.get('type'):
                changes['type'] = 'playback_state_changed'
            changes['state'] = current_state.get('state')
            
        # Check for volume change
        if current_state.get('volume') != self.last_state.get('volume'):
            if not changes.get('type'):
                changes['type'] = 'volume_changed'
            changes['volume'] = current_state.get('volume')
            
        # Don't broadcast position-only updates
        # The client's seek bar will handle smooth animation
        # Only broadcast if there are actual changes above
            
        return changes if changes else None
