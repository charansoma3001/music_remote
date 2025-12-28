"""
Flask server for controlling Apple Music remotely.
Provides REST API endpoints and mDNS service advertisement.
"""

from flask import Flask, jsonify, request, send_file
from flask_socketio import SocketIO, emit, disconnect
from functools import wraps
import socket
from zeroconf import ServiceInfo, Zeroconf
import applescript_commands as asc
from config import Config
from music_monitor import MusicMonitor
import time # Added for socketio ping timestamp

# Initialize Flask app and SocketIO
app = Flask(__name__)
app.config['SECRET_KEY'] = 'music-remote-secret-key'  # Change in production
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='threading')

# Load configuration
config = Config()


def require_auth(f):
    """Decorator to require authentication token for endpoints."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            return jsonify({'error': 'No authorization header provided'}), 401
        
        # Expected format: "Bearer <token>"
        parts = auth_header.split()
        if len(parts) != 2 or parts[0] != 'Bearer':
            return jsonify({'error': 'Invalid authorization header format'}), 401
        
        token = parts[1]
        if token != config.auth_token:
            return jsonify({'error': 'Invalid authentication token'}), 401
        
        return f(*args, **kwargs)
    return decorated_function


# Public endpoint - no auth required
@app.route('/ping', methods=['GET'])
def ping():
    """Health check endpoint."""
    return jsonify({'status': 'ok', 'service': 'Apple Music Remote'})


# Protected endpoints
@app.route('/status', methods=['GET'])
@require_auth
def get_status():
    """Get current playback status."""
    state = asc.get_playback_state()
    volume = asc.get_volume()
    return jsonify({
        'state': state,
        'volume': volume
    })


@app.route('/current-track', methods=['GET'])
@require_auth
def get_current_track():
    """Get current track information."""
    track_info = asc.get_current_track()
    return jsonify(track_info)


@app.route('/play', methods=['POST'])
@require_auth
def play():
    """Start or resume playback."""
    result = asc.play()
    return jsonify({
        'action': 'play',
        'success': True,
        'message': 'Playback started'
    })


@app.route('/pause', methods=['POST'])
@require_auth
def pause():
    """Pause playback."""
    result = asc.pause()
    return jsonify({
        'action': 'pause',
        'success': True,
        'message': 'Playback paused'
    })


@app.route('/next', methods=['POST'])
@require_auth
def next_track():
    """Skip to next track."""
    result = asc.next_track()
    # Small delay to let the track change
    import time
    time.sleep(0.5)
    track_info = asc.get_current_track()
    return jsonify({
        'action': 'next',
        'success': True,
        'track': track_info
    })


@app.route('/previous', methods=['POST'])
@require_auth
def previous_track():
    """Go to previous track."""
    result = asc.previous_track()
    # Small delay to let the track change
    import time
    time.sleep(0.5)
    track_info = asc.get_current_track()
    return jsonify({
        'action': 'previous',
        'success': True,
        'track': track_info
    })


@app.route('/volume', methods=['POST'])
@require_auth
def set_volume():
    """Set volume level."""
    data = request.get_json()
    
    if not data or 'level' not in data:
        return jsonify({'error': 'Volume level not provided'}), 400
    
    try:
        level = int(data['level'])
        result = asc.set_volume(level)
        return jsonify({
            'action': 'set_volume',
            'success': True,
            'level': level
        })
    except ValueError:
        return jsonify({'error': 'Invalid volume level'}), 400


@app.route('/playlists', methods=['GET'])
@require_auth
def get_playlists():
    """Get list of available playlists."""
    playlists = asc.get_playlists()
    return jsonify({
        'playlists': playlists,
        'count': len(playlists)
    })


@app.route('/playlist/<playlist_name>/play', methods=['POST'])
@require_auth
def play_playlist(playlist_name):
    """Play a specific playlist."""
    result = asc.play_playlist(playlist_name)
    return jsonify({
        'action': 'play_playlist',
        'playlist': playlist_name,
        'success': True
    })


@app.route('/artwork', methods=['GET'])
@require_auth
def get_artwork():
    """Get artwork for the current track."""
    import os
    
    artwork_path = asc.get_artwork()
    
    if artwork_path and os.path.exists(artwork_path):
        return send_file(
            artwork_path,
            mimetype='image/jpeg',
            as_attachment=False
        )
    else:
        return jsonify({'error': 'No artwork available'}), 404


@app.route('/seek', methods=['POST'])
@require_auth
def seek():
    """Seek to a specific position in the track."""
    data = request.get_json()
    
    if not data or 'position' not in data:
        return jsonify({'error': 'Position not provided'}), 400
    
    try:
        position = float(data['position'])
        result = asc.seek_to_position(position)
        return jsonify({
            'action': 'seek',
            'success': True,
            'position': position
        })
    except ValueError:
        return jsonify({'error': 'Invalid position'}), 400


@app.route('/search', methods=['GET'])
@require_auth
def search():
    """Search the Apple Music library."""
    query = request.args.get('query', '')
    search_type = request.args.get('type', 'track')
    
    if not query:
        return jsonify({'error': 'Query parameter required'}), 400
    
    if search_type not in ['track', 'album', 'artist']:
        return jsonify({'error': 'Invalid search type'}), 400
    
    try:
        results = asc.search_library(query, search_type)
        return jsonify({
            'query': query,
            'type': search_type,
            'results': results,
            'count': len(results)
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/play-track/<track_id>', methods=['POST'])
@require_auth
def play_track(track_id):
    """Play a specific track by ID."""
    try:
        result = asc.play_track_by_id(track_id)
        import time
        time.sleep(0.5)
        track_info = asc.get_current_track()
        return jsonify({
            'action': 'play_track',
            'success': True,
            'track': track_info
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/device/register', methods=['POST'])
@require_auth
def register_device():
    """Register a device as trusted."""
    from trusted_devices import TrustedDeviceManager
    
    data = request.get_json()
    if not data or 'device_fingerprint' not in data:
        return jsonify({'error': 'Device fingerprint required'}), 400
    
    device_manager = TrustedDeviceManager(config.config_dir)
    device_manager.add_device(
        data['device_fingerprint'],
        data.get('device_name', 'Unknown Device')
    )
    
    return jsonify({
        'success': True,
        'message': 'Device registered as trusted'
    })


@app.route('/device/check', methods=['POST'])
def check_device():
    """Check if a device is trusted (no auth required for this)."""
    from trusted_devices import TrustedDeviceManager
    
    data = request.get_json()
    if not data or 'device_fingerprint' not in data:
        return jsonify({'error': 'Device fingerprint required'}), 400
    
    device_manager = TrustedDeviceManager(config.config_dir)
    is_trusted = device_manager.is_trusted(data['device_fingerprint'])
    
    return jsonify({
        'is_trusted': is_trusted,
        'requires_token': not is_trusted
    })


@app.route('/device/list', methods=['GET'])
@require_auth
def list_devices():
    """List all trusted devices."""
    from trusted_devices import TrustedDeviceManager
    
    device_manager = TrustedDeviceManager(config.config_dir)
    devices = device_manager.get_all_devices()
    
    return jsonify({
        'devices': devices,
        'count': len(devices)
    })


@app.route('/device/remove/<device_fingerprint>', methods=['DELETE'])
@require_auth
def remove_device(device_fingerprint):
    """Remove a trusted device."""
    from trusted_devices import TrustedDeviceManager
    
    device_manager = TrustedDeviceManager(config.config_dir)
    success = device_manager.remove_device(device_fingerprint)
    
    if success:
        return jsonify({'success': True, 'message': 'Device removed'})
    else:
        return jsonify({'error': 'Device not found'}), 404


@app.route('/repeat', methods=['GET'])
@require_auth
def get_repeat():
    """Get current repeat mode."""
    mode = asc.get_repeat_mode()
    return jsonify({'repeat': mode})


@app.route('/repeat', methods=['POST'])
@require_auth
def set_repeat():
    """Set repeat mode (off, one, all)."""
    data = request.get_json()
    mode = data.get('mode', 'off')
    
    if mode not in ['off', 'one', 'all']:
        return jsonify({'error': 'Invalid mode. Use: off, one, or all'}), 400
    
    result = asc.set_repeat_mode(mode)
    return jsonify({'action': 'set_repeat', 'mode': mode, 'result': result})


@app.route('/shuffle', methods=['GET'])
@require_auth
def get_shuffle():
    """Get current shuffle mode."""
    enabled = asc.get_shuffle_mode()
    return jsonify({'shuffle': enabled})


@app.route('/shuffle', methods=['POST'])
@require_auth
def set_shuffle():
    """Set shuffle mode."""
    data = request.get_json()
    enabled = data.get('enabled', False)
    
    result = asc.set_shuffle_mode(enabled)
    return jsonify({'action': 'set_shuffle', 'enabled': enabled, 'result': result})

# WebSocket event handlers

@socketio.on('connect')
def handle_connect():
    """Handle client connection."""
    # Get auth token from query params or headers
    auth_token = request.args.get('token')
    
    if not auth_token or auth_token != config.auth_token:
        print(f"❌ WebSocket auth failed from {request.remote_addr}")
        disconnect()
        return False
    
    print(f"✅ WebSocket client connected: {request.sid}")
    # Send initial state
    try:
        track = asc.get_current_track()
        status = asc.get_playback_state() # Changed from get_player_state() to get_playback_state() for consistency
        emit('initial_state', {
            'track': track,
            'status': status
        })
    except Exception as e:
        print(f"Error sending initial state: {e}")


@socketio.on('disconnect')
def handle_disconnect():
    """Handle client disconnection."""
    print(f"❌ WebSocket client disconnected: {request.sid}")


@socketio.on('ping')
def handle_ping():
    """Handle ping from client."""
    emit('pong', {'timestamp': time.time()})


# Music monitor callback
def on_music_change(changes):
    """Broadcast music state changes to all connected clients."""
    try:
        socketio.emit('music_update', changes)
        print(f"📢 Broadcast: {changes.get('type')}")
    except Exception as e:
        print(f"Broadcast error: {e}")


# Initialize music monitor
music_monitor = MusicMonitor(on_change_callback=on_music_change)
music_monitor.start()


# Global variables for zeroconf
zeroconf = None
service_info = None

def get_local_ip():
    """Get the local IP address of this machine."""
    try:
        # Create a socket and connect to an external address to determine local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except Exception:
        return "127.0.0.1"


def start_mdns_service(local_ip, port):
    """Advertise the service via mDNS/Zeroconf."""
    global zeroconf, service_info
    
    print(f"\n📡 Starting mDNS service advertisement...")
    print(f"   Local IP: {local_ip}")
    print(f"   Port: {port}\n")
    
    zeroconf = Zeroconf()
    
    service_info = ServiceInfo(
        "_applemusic._tcp.local.",
        "MacMusicRemote._applemusic._tcp.local.",
        addresses=[socket.inet_aton(local_ip)],
        port=port,
        properties={'version': '1.0', 'name': 'Apple Music Remote'},
        server=f"{socket.gethostname()}.local."
    )
    
    zeroconf.register_service(service_info)
    print("✅ mDNS service registered successfully!")
    print(f"   Service name: MacMusicRemote._applemusic._tcp.local.\n")


if __name__ == '__main__':
    try:
        # Display token and QR code
        config.display_token()
        
        # Get local IP and start mDNS
        local_ip = get_local_ip()
        start_mdns_service(local_ip, config.port)
        
        # Display QR code for mobile
        server_url = f'http://{local_ip}:{config.port}'
        config.display_qr_code(server_url)
        
        print(f"\n🚀 Starting Flask server with WebSocket on {config.host}:{config.port}")
        print(f"   Access at: {server_url}")
        print(f"\n📡 WebSocket endpoint: ws://{local_ip}:{config.port}/socket.io/")
        print("\nPress Ctrl+C to stop the server\n")
        
        # Run with SocketIO
        socketio.run(
            app,
            host=config.host,
            port=config.port,
            debug=False,
            allow_unsafe_werkzeug=True
        )
    except KeyboardInterrupt:
        print("\n✅ Server stopped successfully")
        music_monitor.stop()
    finally:
        if zeroconf:
            zeroconf.unregister_service(service_info)
            zeroconf.close()
