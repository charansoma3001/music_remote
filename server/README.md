# Apple Music Remote - Python Server

A Flask-based REST API server that allows remote control of Apple Music on macOS via AppleScript commands. The server advertises itself on the local network using mDNS for automatic discovery.

## Features

- 🎵 Control Apple Music playback (play, pause, next, previous)
- 📊 Get current track information (title, artist, album, duration)
- 🔊 Adjust volume remotely
- 📱 mDNS service advertisement for auto-discovery
- 🔐 Token-based authentication for security
- 📋 Playlist management

## Prerequisites

- **macOS** (required for AppleScript to control Apple Music)
- **Python 3.9+**
- **Apple Music** installed and accessible

## Installation

1. **Navigate to the server directory:**
   ```bash
   cd server
   ```

2. **Create a virtual environment:**
   ```bash
   python3 -m venv venv
   ```

3. **Activate the virtual environment:**
   ```bash
   source venv/bin/activate
   ```

4. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

## Usage

### Starting the Server

```bash
python server.py
```

On first run, the server will:
1. Generate a unique authentication token
2. Save it to `~/.music_remote/auth_token.txt`
3. Display the token in the terminal (**copy this for your Flutter app**)
4. Start the Flask server on port 5000
5. Advertise the service via mDNS as `MacMusicRemote._applemusic._tcp.local.`

### API Endpoints

All endpoints except `/ping` require authentication via `Authorization: Bearer <token>` header.

#### Health Check
```bash
GET /ping
# No authentication required
```

#### Playback Control
```bash
POST /play          # Start/resume playback
POST /pause         # Pause playback
POST /next          # Skip to next track
POST /previous      # Go to previous track
```

#### Status & Info
```bash
GET /status         # Get playback state and volume
GET /current-track  # Get current track details
```

#### Volume Control
```bash
POST /volume
Body: {"level": 50}  # Set volume (0-100)
```

#### Playlists
```bash
GET /playlists                    # List all playlists
POST /playlist/<name>/play        # Play specific playlist
```

### Testing with cURL

```bash
# Set your token
TOKEN="your_token_here"

# Get current track
curl -H "Authorization: Bearer $TOKEN" http://localhost:5000/current-track

# Play
curl -X POST -H "Authorization: Bearer $TOKEN" http://localhost:5000/play

# Set volume to 75
curl -X POST -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"level": 75}' \
  http://localhost:5000/volume
```

## Configuration

The server uses the following configuration (can be set via environment variables):

- `SERVER_HOST`: Host to bind to (default: `0.0.0.0`)
- `SERVER_PORT`: Port to listen on (default: `5000`)

## Security

- The server generates a random authentication token on first run
- Token is saved to `~/.music_remote/auth_token.txt`
- All endpoints (except `/ping`) require valid Bearer token
- Server only listens on local network by default

## Troubleshooting

### "Permission Denied" for Apple Music
Make sure to grant Terminal (or your IDE) accessibility permissions:
1. Go to **System Preferences** → **Security & Privacy** → **Privacy** → **Accessibility**
2. Add and enable your terminal application

### Service Not Discoverable
- Ensure both Mac and mobile device are on the same WiFi network
- Check firewall settings aren't blocking port 5000
- Verify mDNS/Bonjour is enabled on your network

### AppleScript Errors
- Ensure Apple Music is installed and can be launched
- Try running a command manually: `osascript -e 'tell application "Music" to get player state'`

## Project Structure

```
server/
├── server.py                 # Main Flask application
├── applescript_commands.py   # AppleScript wrapper functions
├── config.py                 # Configuration & token management
├── requirements.txt          # Python dependencies
└── README.md                # This file
```

## Development

To run in debug mode, modify `server.py`:

```python
app.run(host=config.host, port=config.port, debug=True)
```

## License

MIT
