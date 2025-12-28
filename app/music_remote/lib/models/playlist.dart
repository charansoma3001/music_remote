/// Model for playlist information
class Playlist {
  final String name;
  final int? trackCount;

  Playlist({required this.name, this.trackCount});

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      name: json['name'] as String,
      trackCount: json['trackCount'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'trackCount': trackCount};
  }
}
