import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/track_info.dart';

/// Service for communicating with the Apple Music remote server
class MusicApiService {
  final String baseUrl;
  final String authToken;

  MusicApiService({required this.baseUrl, required this.authToken});

  /// Get authorization headers
  Map<String, String> get _headers => {
    'Authorization': 'Bearer $authToken',
    'Content-Type': 'application/json',
  };

  /// Test connection to server
  Future<bool> ping() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/ping'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get current playback status
  Future<Map<String, dynamic>> getStatus() async {
    final response = await http
        .get(Uri.parse('$baseUrl/status'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get status: ${response.statusCode}');
    }
  }

  /// Get current track information
  Future<TrackInfo> getCurrentTrack() async {
    final response = await http
        .get(Uri.parse('$baseUrl/current-track'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      return TrackInfo.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to get current track: ${response.statusCode}');
    }
  }

  /// Start or resume playback
  Future<void> play() async {
    final response = await http
        .post(Uri.parse('$baseUrl/play'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to play: ${response.statusCode}');
    }
  }

  /// Pause playback
  Future<void> pause() async {
    final response = await http
        .post(Uri.parse('$baseUrl/pause'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to pause: ${response.statusCode}');
    }
  }

  /// Skip to next track
  Future<TrackInfo> nextTrack() async {
    final response = await http
        .post(Uri.parse('$baseUrl/next'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TrackInfo.fromJson(data['track']);
    } else {
      throw Exception('Failed to skip track: ${response.statusCode}');
    }
  }

  /// Go to previous track
  Future<TrackInfo> previousTrack() async {
    final response = await http
        .post(Uri.parse('$baseUrl/previous'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TrackInfo.fromJson(data['track']);
    } else {
      throw Exception('Failed to go to previous track: ${response.statusCode}');
    }
  }

  /// Set volume level (0-100)
  Future<void> setVolume(int level) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/volume'),
          headers: _headers,
          body: jsonEncode({'level': level}),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to set volume: ${response.statusCode}');
    }
  }

  /// Get list of available playlists
  Future<List<String>> getPlaylists() async {
    final response = await http
        .get(Uri.parse('$baseUrl/playlists'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['playlists']);
    } else {
      throw Exception('Failed to get playlists: ${response.statusCode}');
    }
  }

  /// Play a specific playlist
  Future<void> playPlaylist(String playlistName) async {
    final encodedName = Uri.encodeComponent(playlistName);
    final response = await http
        .post(
          Uri.parse('$baseUrl/playlist/$encodedName/play'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to play playlist: ${response.statusCode}');
    }
  }

  /// Get artwork URL for current track
  String getArtworkUrl() {
    // Don't add timestamp - let CachedNetworkImage handle caching
    return '$baseUrl/artwork';
  }

  /// Seek to a specific position in the track
  Future<void> seekToPosition(double position) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/seek'),
          headers: _headers,
          body: jsonEncode({'position': position}),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to seek: ${response.statusCode}');
    }
  }

  /// Search the library
  Future<List<Map<String, dynamic>>> search(
    String query, {
    String type = 'track',
  }) async {
    final response = await http
        .get(
          Uri.parse(
            '$baseUrl/search?query=${Uri.encodeComponent(query)}&type=$type',
          ),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(data['results'] ?? []);
    } else {
      throw Exception('Failed to search: ${response.statusCode}');
    }
  }

  /// Play a specific track by ID
  Future<TrackInfo> playTrackById(String trackId) async {
    final response = await http
        .post(Uri.parse('$baseUrl/play-track/$trackId'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TrackInfo.fromJson(data['track']);
    } else {
      throw Exception('Failed to play track: ${response.statusCode}');
    }
  }

  /// Register device as trusted
  Future<void> registerDevice(String fingerprint, String deviceName) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/device/register'),
          headers: _headers,
          body: jsonEncode({
            'device_fingerprint': fingerprint,
            'device_name': deviceName,
          }),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to register device: ${response.statusCode}');
    }
  }

  /// Get repeat mode
  Future<String> getRepeat() async {
    final response = await http
        .get(Uri.parse('$baseUrl/repeat'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['repeat'] as String;
    } else {
      throw Exception('Failed to get repeat: ${response.statusCode}');
    }
  }

  /// Set repeat mode
  Future<void> setRepeat(String mode) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/repeat'),
          headers: _headers,
          body: jsonEncode({'mode': mode}),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to set repeat: ${response.statusCode}');
    }
  }

  /// Get shuffle mode
  Future<bool> getShuffle() async {
    final response = await http
        .get(Uri.parse('$baseUrl/shuffle'), headers: _headers)
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['shuffle'] as bool;
    } else {
      throw Exception('Failed to get shuffle: ${response.statusCode}');
    }
  }

  /// Set shuffle mode
  Future<void> setShuffle(bool enabled) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/shuffle'),
          headers: _headers,
          body: jsonEncode({'enabled': enabled}),
        )
        .timeout(const Duration(seconds: 5));

    if (response.statusCode != 200) {
      throw Exception('Failed to set shuffle: ${response.statusCode}');
    }
  }
}
