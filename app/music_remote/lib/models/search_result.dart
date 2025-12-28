/// Model for search result
class SearchResult {
  final String type; // 'track', 'album', or 'artist'
  final String name;
  final String? artist;
  final String? album;
  final String? id;

  SearchResult({
    required this.type,
    required this.name,
    this.artist,
    this.album,
    this.id,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      type: json['type'] as String,
      name: json['name'] as String,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      id: json['id'] as String?,
    );
  }
}
