# Apple Music Remote - Flutter App

A Flutter mobile app for remotely controlling Apple Music on your Mac. Connects to a Python server running on macOS to control playback, view track information, and adjust volume.

## Features

- 🎵 Remote playback control (play, pause, next, previous)
- 📱 Real-time track information display
- 🔊 Volume control
- 🔐 Secure token-based authentication
- 💾 Automatic reconnection to saved server
- ♻️ Auto-refresh track info every 3 seconds

## Prerequisites

- **Flutter SDK** 3.0 or higher
- **Android Studio** or **Xcode** for building
- **Python server** running on your Mac (see `../server/README.md`)
- Both devices must be on the same WiFi network

## Installation

1. **Navigate to the app directory:**
   ```bash
   cd app/music_remote
   ```

2. **Get dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run
   ```

## First-Time Setup

1. **Start the Python server on your Mac** (see server README)
2. **Note the server details:**
   - IP address (e.g., `192.168.1.100`)
   - Port (default: `5000`)
   - Authentication token (displayed in terminal)

3. **In the Flutter app:**
   - Enter the server URL: `http://<IP_ADDRESS>:5000`
   - Paste the authentication token
   - Tap "Connect"

4. **Start controlling your music!** 🎉

## Building for Release

### Android
```bash
flutter build apk --release
# APK will be at: build/app/outputs/flutter-apk/app-release.apk
```

### iOS
```bash
flutter build ios --release
# Then open ios/Runner.xcworkspace in Xcode to archive and distribute
```

## Project Structure

```
lib/
├── main.dart                       # App entry point with provider setup
├── models/
│   └── track_info.dart            # Track data model
├── services/
│   └── music_api_service.dart     # HTTP API client
├── providers/
│   └── music_provider.dart        # State management
└── screens/
    ├── discovery_screen.dart      # Server connection screen
    └── control_screen.dart        # Main playback control screen
```

## Usage

### Discovery Screen
- First-time connection setup
- Manual server URL entry
- Token authentication
- Connection status feedback

### Control Screen
- **Album art** (placeholder for now)
- **Track information** (title, artist, album)
- **Playback controls** (play/pause, next, previous)
- **Progress bar** (display only, seek not yet implemented)
- **Volume slider** (0-100)
- **Connection status** indicator
- **Pull to refresh** track info manually

## Troubleshooting

### "Connection Failed"
- Verify server is running on Mac
- Check that both devices are on same WiFi
- Confirm server URL is correct (use the IP shown in server terminal)
- Ensure token is copied correctly

### "Server Not Reachable"
- Check Mac firewall settings
- Verify port 5000 is not blocked
- Try pinging the Mac from your phone's browser: `http://<mac-ip>:5000/ping`

## License

MIT
