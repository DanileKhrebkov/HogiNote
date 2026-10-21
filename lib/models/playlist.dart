/// Модель локального плейлиста.
class Playlist {
  final int? id;
  final String name;
  final int createdAt;

  const Playlist({
    this.id,
    required this.name,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt,
      };

  factory Playlist.fromMap(Map<String, Object?> map) => Playlist(
        id: map['id'] as int?,
        name: map['name'] as String,
        createdAt: map['created_at'] as int,
      );

  DateTime get createdDate =>
      DateTime.fromMillisecondsSinceEpoch(createdAt);
}
