/// Модель скачанного трека (хранится в SQLite и на диске).
class Track {
  final int? id;
  final String youtubeId;
  final String title;
  final String author;
  final int durationMs;
  final String filePath;
  final int downloadedAt;

  const Track({
    this.id,
    required this.youtubeId,
    required this.title,
    required this.author,
    required this.durationMs,
    required this.filePath,
    required this.downloadedAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'youtube_id': youtubeId,
        'title': title,
        'author': author,
        'duration_ms': durationMs,
        'file_path': filePath,
        'downloaded_at': downloadedAt,
      };

  factory Track.fromMap(Map<String, Object?> map) => Track(
        id: map['id'] as int?,
        youtubeId: map['youtube_id'] as String,
        title: map['title'] as String,
        author: map['author'] as String,
        durationMs: map['duration_ms'] as int,
        filePath: map['file_path'] as String,
        downloadedAt: map['downloaded_at'] as int,
      );

  Duration get duration => Duration(milliseconds: durationMs);

  Track copyWith({int? id}) => Track(
        id: id ?? this.id,
        youtubeId: youtubeId,
        title: title,
        author: author,
        durationMs: durationMs,
        filePath: filePath,
        downloadedAt: downloadedAt,
      );
}

/// Результат поиска на YouTube (ещё не скачанный трек).
class SearchResultItem {
  final String videoId;
  final String title;
  final String author;
  final Duration duration;

  const SearchResultItem({
    required this.videoId,
    required this.title,
    required this.author,
    required this.duration,
  });
}
