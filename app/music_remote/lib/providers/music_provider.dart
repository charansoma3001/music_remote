import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/track_info.dart';
import '../models/search_result.dart';
import '../services/music_api_service.dart';
import '../services/websocket_service.dart';

/// Provider for managing music playback state
class MusicProvider with ChangeNotifier {
  MusicApiService? _apiService;
  WebSocketService? _websocketService;
  TrackInfo _currentTrack = TrackInfo();
  String? _errorMessage;
  Timer? _refreshTimer;
  Timer? _positionTimer; // For smooth position updates
  String _repeatMode = 'off'; // 'off', 'one', 'all'
  bool _isShuffleEnabled = false;
  bool _useWebSocket = true; // Toggle between WebSocket and polling
  double _volume = 0.5;

  // Getters
  TrackInfo get currentTrack => _currentTrack;
  double get volume => _volume;
  String? get errorMessage => _errorMessage;
  bool get isConnected => _apiService != null;
  String? get authToken => _apiService?.authToken;
  String get repeatMode => _repeatMode;
  bool get isShuffleEnabled => _isShuffleEnabled;
  bool get isPlaying => _currentTrack.isPlaying;

  /// Initialize with saved connection settings
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('server_url');
    final authToken = prefs.getString('auth_token');

    if (serverUrl != null && authToken != null) {
      await connect(serverUrl, authToken);
    }
  }

  /// Connect to the server
  Future<bool> connect(String serverUrl, String authToken) async {
    try {
      _apiService = MusicApiService(baseUrl: serverUrl, authToken: authToken);

      // Test connection
      final isReachable = await _apiService!.ping();

      if (isReachable) {
        // Connected successfully
        _errorMessage = null;

        // Save connection settings
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('server_url', serverUrl);
        await prefs.setString('auth_token', authToken);

        // Setup WebSocket for real-time updates (primary)
        if (_useWebSocket) {
          _setupWebSocket(serverUrl, authToken);
          // Don't start polling - WebSocket will handle updates
          // If WebSocket fails, onDisconnected callback will start polling
        } else {
          // Fallback to polling if WebSocket disabled
          _startAutoRefresh();
        }

        // Initial data fetch
        await refresh();

        notifyListeners();
        return true;
      } else {
        // Connection failed
        notifyListeners();
        _errorMessage = 'Server not reachable';
        notifyListeners();
        return false;
      }
    } catch (e) {
      // Connection failed
      notifyListeners();
      _errorMessage = 'Connection failed: $e';
      notifyListeners();
      return false;
    }
  }

  /// Setup WebSocket connection for real-time updates
  void _setupWebSocket(String serverUrl, String authToken) {
    if (!_useWebSocket) return;

    _websocketService = WebSocketService(
      serverUrl: serverUrl,
      authToken: authToken,
    );

    _websocketService!.onConnected = () {
      print('🎵 WebSocket connected - stopping polling');
      _stopAutoRefresh(); // Stop polling when WebSocket connects
    };

    _websocketService!.onDisconnected = () {
      print('⚠️ WebSocket disconnected - falling back to polling');
      _startAutoRefresh(); // Restart polling as fallback
    };

    _websocketService!.onMusicUpdate = (data) {
      _handleWebSocketUpdate(data);
    };

    _websocketService!.connect();
  }

  /// Handle WebSocket music updates
  void _handleWebSocketUpdate(Map<String, dynamic> data) {
    try {
      final type = data['type'];
      print('📢 WebSocket update: $type');

      // Handle different update types
      if (type == 'initial_state' || type == 'full_update') {
        // Full state update
        refresh(); // Do a full refresh
      } else if (type == 'track_changed') {
        // Track changed - refresh everything and reset position timer
        refresh().then((_) => _startPositionTimer());
      } else if (type == 'playback_state_changed') {
        // Play/pause state changed
        if (data['state'] != null) {
          final newState = data['state'] as String;
          _currentTrack = TrackInfo(
            name: _currentTrack.name,
            artist: _currentTrack.artist,
            album: _currentTrack.album,
            duration: _currentTrack.duration,
            position: _currentTrack.position,
            state: newState,
          );

          // Start/stop position timer based on state
          if (newState == 'playing') {
            _startPositionTimer();
          } else {
            _stopPositionTimer();
          }

          notifyListeners();
        }
      } else if (type == 'volume_changed') {
        if (data['volume'] != null) {
          _volume = (data['volume'] as num).toDouble();
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error handling WebSocket update: $e');
    }
  }

  /// Disconnect from server
  void disconnect() {
    _stopAutoRefresh();
    _stopPositionTimer();
    _websocketService?.disconnect();
    _websocketService = null;
    _apiService = null;
    // Disconnected
    _currentTrack = TrackInfo();
    _errorMessage = null;
    notifyListeners();
  }

  /// Clear saved connection settings
  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('server_url');
    await prefs.remove('auth_token');

    // Also clear secure storage
    const secureStorage = FlutterSecureStorage();
    await secureStorage.delete(key: 'server_url');
    await secureStorage.delete(key: 'auth_token');

    disconnect();
  }

  /// Start auto-refresh timer
  void _startAutoRefresh() {
    _stopAutoRefresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => refresh(),
    );
  }

  /// Stop auto-refresh timer
  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Start position interpolation timer
  void _startPositionTimer() {
    _stopPositionTimer();

    if (!_currentTrack.isPlaying) return;

    // Update position every second while playing
    _positionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentTrack.isPlaying) {
        final newPosition = _currentTrack.position + 1.0;

        // Clamp position to duration to prevent overflow
        final clampedPosition = newPosition.clamp(0.0, _currentTrack.duration);

        _currentTrack = TrackInfo(
          name: _currentTrack.name,
          artist: _currentTrack.artist,
          album: _currentTrack.album,
          duration: _currentTrack.duration,
          position: clampedPosition,
          state: _currentTrack.state,
        );
        notifyListeners();

        // Stop timer if we've reached the end
        if (clampedPosition >= _currentTrack.duration) {
          _stopPositionTimer();
        }
      }
    });
  }

  /// Stop position interpolation timer
  void _stopPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = null;
  }

  /// Refresh current track info and status
  Future<void> refresh() async {
    if (_apiService == null || !isConnected) return;

    try {
      // Fetch current track and status in parallel
      final results = await Future.wait([
        _apiService!.getCurrentTrack(),
        _apiService!.getStatus(),
      ]);

      _currentTrack = results[0] as TrackInfo;
      final status = results[1] as Map<String, dynamic>;
      _volume = (status['volume'] ?? 50).toDouble();
      _errorMessage = null;

      // Start position timer if playing (important for reconnection)
      if (_currentTrack.isPlaying) {
        _startPositionTimer();
      } else {
        _stopPositionTimer();
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to refresh: $e';
      // Failed to refresh
      notifyListeners();
    }
  }

  /// Play/resume playback
  Future<void> play() async {
    if (_apiService == null) return;

    try {
      await _apiService!.play();
      _startPositionTimer(); // Start local position updates
      await refresh(); // Refresh to get actual state from server
    } catch (e) {
      _errorMessage = 'Failed to play: $e';
      notifyListeners();
    }
  }

  /// Pause playback
  Future<void> pause() async {
    if (_apiService == null) return;

    try {
      await _apiService!.pause();
      _stopPositionTimer(); // Stop local position updates
      await refresh(); // Refresh to get actual state from server
    } catch (e) {
      _errorMessage = 'Failed to pause: $e';
      notifyListeners();
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_currentTrack.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Skip to next track
  Future<void> next() async {
    if (_apiService == null) return;

    try {
      final track = await _apiService!.nextTrack();
      _currentTrack = track;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to skip track: $e';
      notifyListeners();
    }
  }

  /// Go to previous track
  Future<void> previous() async {
    if (_apiService == null) return;

    try {
      final track = await _apiService!.previousTrack();
      _currentTrack = track;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to go to previous: $e';
      notifyListeners();
    }
  }

  /// Set volume level
  Future<void> setVolume(int level) async {
    if (_apiService == null) return;

    try {
      await _apiService!.setVolume(level);
      _volume = level.toDouble();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to set volume: $e';
      notifyListeners();
    }
  }

  /// Seek to a specific position in the track
  Future<void> seekToPosition(double position) async {
    if (_apiService == null) return;

    try {
      // Immediately update local position for responsive UI
      _currentTrack = TrackInfo(
        name: _currentTrack.name,
        artist: _currentTrack.artist,
        album: _currentTrack.album,
        duration: _currentTrack.duration,
        position: position,
        state: _currentTrack.state,
        artworkUrl: _currentTrack.artworkUrl,
      );
      notifyListeners();

      // Send seek request to server
      await _apiService!.seekToPosition(position);

      // Restart position timer if playing
      if (_currentTrack.isPlaying) {
        _startPositionTimer();
      }
      // Refresh after a short delay to get actual position
      await Future.delayed(const Duration(milliseconds: 500));
      await refresh();
    } catch (e) {
      _errorMessage = 'Failed to seek: $e';
      notifyListeners();
    }
  }

  /// Get artwork URL for current track
  String? get artworkUrl {
    if (_apiService == null || !_currentTrack.hasTrack) return null;
    return _apiService!.getArtworkUrl();
  }

  /// Register device as trusted
  Future<void> registerDevice(String fingerprint, String deviceName) async {
    if (_apiService == null) return;
    try {
      await _apiService!.registerDevice(fingerprint, deviceName);
    } catch (e) {
      print('Failed to register device: $e');
    }
  }

  /// Toggle shuffle
  Future<void> toggleShuffle() async {
    if (_apiService == null) return;
    try {
      _isShuffleEnabled = !_isShuffleEnabled;
      notifyListeners();
      await _apiService!.setShuffle(_isShuffleEnabled);
    } catch (e) {
      _errorMessage = 'Failed to toggle shuffle: $e';
      notifyListeners();
    }
  }

  /// Cycle through repeat modes (off -> all -> one -> off)
  Future<void> cycleRepeat() async {
    if (_apiService == null) return;
    try {
      // Cycle: off -> all -> one -> off
      if (_repeatMode == 'off') {
        _repeatMode = 'all';
      } else if (_repeatMode == 'all') {
        _repeatMode = 'one';
      } else {
        _repeatMode = 'off';
      }
      notifyListeners();
      await _apiService!.setRepeat(_repeatMode);
    } catch (e) {
      _errorMessage = 'Failed to set repeat: $e';
      notifyListeners();
    }
  }

  /// Refresh repeat/shuffle state from server
  Future<void> _refreshRepeatShuffle() async {
    if (_apiService == null) return;
    try {
      final repeat = await _apiService!.getRepeat();
      final shuffle = await _apiService!.getShuffle();
      _repeatMode = repeat;
      _isShuffleEnabled = shuffle;
      notifyListeners();
    } catch (e) {
      print('Failed to refresh repeat/shuffle: $e');
    }
  }

  /// Get list of playlists
  Future<List<String>> getPlaylists() async {
    if (_apiService == null) throw Exception('Not connected to server');
    return await _apiService!.getPlaylists();
  }

  /// Play a specific playlist
  Future<void> playPlaylist(String playlistName) async {
    if (_apiService == null) return;

    try {
      await _apiService!.playPlaylist(playlistName);
      // Refresh after playlist starts playing
      await Future.delayed(const Duration(seconds: 1));
      await refresh();
    } catch (e) {
      _errorMessage = 'Failed to play playlist: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Search the library
  Future<List<SearchResult>> search(
    String query, {
    String type = 'track',
  }) async {
    if (_apiService == null) throw Exception('Not connected to server');
    final results = await _apiService!.search(query, type: type);
    return results.map((r) => SearchResult.fromJson(r)).toList();
  }

  /// Play a track by ID
  Future<void> playTrackById(String trackId) async {
    if (_apiService == null) return;

    try {
      final track = await _apiService!.playTrackById(trackId);
      _currentTrack = track;
      notifyListeners();
      // Refresh to get latest state
      await Future.delayed(const Duration(milliseconds: 500));
      await refresh();
    } catch (e) {
      _errorMessage = 'Failed to play track: $e';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _stopAutoRefresh();
    _stopPositionTimer();
    _websocketService?.disconnect();
    _websocketService?.dispose();
    super.dispose();
  }
}
