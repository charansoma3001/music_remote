/// Data model for track information received from the server
class TrackInfo {
  final String? name;
  final String? artist;
  final String? album;
  final double duration;
  final double position;
  final String state;
  final String? artworkUrl;

  TrackInfo({
    this.name,
    this.artist,
    this.album,
    this.duration = 0,
    this.position = 0,
    this.state = 'stopped',
    this.artworkUrl,
  });

  factory TrackInfo.fromJson(Map<String, dynamic> json) {
    return TrackInfo(
      name: json['name'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      duration: (json['duration'] ?? 0).toDouble(),
      position: (json['position'] ?? 0).toDouble(),
      state: json['state'] as String? ?? 'stopped',
      artworkUrl: json['artworkUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'artist': artist,
      'album': album,
      'duration': duration,
      'position': position,
      'state': state,
      'artworkUrl': artworkUrl,
    };
  }

  bool get hasTrack => name != null && name!.isNotEmpty;

  bool get hasArtwork => artworkUrl != null && artworkUrl!.isNotEmpty;

  bool get isPlaying => state == 'playing';

  bool get isPaused => state == 'paused';

  bool get isStopped => state == 'stopped';

  String get displayDuration {
    final minutes = (duration / 60).floor();
    final seconds = (duration % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get displayPosition {
    final minutes = (position / 60).floor();
    final seconds = (position % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
