# 🎵 Apple Music Remote Control

A complete remote control system for Apple Music on macOS, consisting of a Python REST API server and a Flutter mobile app. Control your Mac's music playback from your phone over the local network!

![Project Status](https://img.shields.io/badge/status-MVP%20Complete-brightgreen)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20Android-blue)

## 📖 Overview

This project allows you to remotely control Apple Music running on your Mac from an iOS or Android device. The system uses:

- **Python Flask Server** (Mac) - REST API that executes AppleScript commands
- **Flutter Mobile App** (iOS/Android) - Beautiful UI for remote control
- **Local Network Communication** - mDNS service discovery + token authentication

## ✨ Features

### Server (Python)
- 🎵 Full playback control (play, pause, next, previous)
- 📊 Current track information retrieval
- 🔊 Volume control
- 📋 Playlist management
- 🔐 Token-based authentication
- 📡 mDNS/Zeroconf service advertisement

### Mobile App (Flutter)
- 📱 Clean, intuitive Material Design 3 interface
- 🔄 Auto-refresh track info every 3 seconds
- 💾 Saved connection settings
- 🎚️ Volume slider control
- ⚡ Real-time playback status
- 🔌 Connection status indicator

## 🚀 Quick Start

### 1. Set Up the Server (Mac)

```bash
cd server
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python server.py
```

**Note:** Copy the authentication token displayed in the terminal!

### 2. Set Up the Mobile App

```bash
cd app/music_remote
flutter pub get
flutter run
```

### 3. Connect

1. In the app, enter your Mac's IP address with port `5000`
2. Paste the authentication token from the server
3. Tap "Connect"
4. Start controlling your music! 🎉

## 📂 Project Structure

```
music_remote/
├── server/                    # Python Flask backend
│   ├── server.py             # Main Flask application
│   ├── applescript_commands.py  # AppleScript wrapper
│   ├── config.py             # Configuration & auth
│   ├── requirements.txt      # Python dependencies
│   └── README.md            # Server documentation
│
├── app/music_remote/         # Flutter mobile app
│   ├── lib/
│   │   ├── main.dart        # App entry point
│   │   ├── models/          # Data models
│   │   ├── services/        # API client
│   │   ├── providers/       # State management
│   │   └── screens/         # UI screens
│   └── README.md           # App documentation
│
└── README.md               # This file
```

## 📱 Screenshots

coming soon...

## 🛠️ Requirements

### Server
- macOS (required for AppleScript)
- Python 3.9+
- Apple Music installed

### Mobile App
- Flutter 3.0+
- iOS device or Android device
- Same WiFi network as Mac

## 🔧 Configuration

### Server
- Port: `5000` (default, configurable via `SERVER_PORT`)
- Token stored in: `~/.music_remote/auth_token.txt`

### App
- Connection settings saved locally with `shared_preferences`

## 🧪 Testing

### Test Server Endpoints
```bash
# Get current track
curl -H "Authorization: Bearer YOUR_TOKEN" http://localhost:5000/current-track

# Play
curl -X POST -H "Authorization: Bearer YOUR_TOKEN" http://localhost:5000/play
```

### Test App
```bash
flutter run
# or for release build
flutter build apk --release
```

## 🐛 Troubleshooting

### Connection Issues
- Ensure both devices are on the same WiFi network
- Check macOS firewall settings (allow Python/Flask)
- Verify the IP address is correct

### AppleScript Permission
- Grant Terminal accessibility permissions in System Preferences
- Path: **Security & Privacy** → **Privacy** → **Accessibility**

### Port Already in Use
```bash
# Find process using port 5000
lsof -i :5000
# Kill if needed
kill -9 <PID>
```

## 📝 API Documentation

See [server/README.md](server/README.md) for complete API endpoint documentation.

## 🔮 Future Enhancements

- [ ] Automatic mDNS discovery in Flutter app
- [ ] Album artwork display
- [ ] Seek/scrub functionality
- [ ] Search songs and playlists
- [ ] Queue management
- [ ] WebSocket for real-time updates
- [ ] Dark mode theme
- [ ] Remote access via tunnel/VPN

## 📄 License

MIT

## 🙏 Credits

Built following Apple Music control best practices and modern mobile app development patterns.

---

**Enjoy your music** 🎶
