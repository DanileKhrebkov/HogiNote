import 'package:xml/xml.dart';

import '../models/playlist.dart';
import '../models/track.dart';

/// Одна строка импортируемого XML-плейлиста.
class XmlPlaylistEntry {
  final String youtubeId;
  final String title;
  final String author;

  const XmlPlaylistEntry({
    required this.youtubeId,
    required this.title,
    required this.author,
  });
}

/// Результат парсинга XML: имя плейлиста + элементы.
class ParsedXmlPlaylist {
  final String name;
  final List<XmlPlaylistEntry> tracks;

  const ParsedXmlPlaylist({required this.name, required this.tracks});
}

/// Формат:
/// ```xml
/// <?xml version="1.0" encoding="UTF-8"?>
/// <hoginote-playlist name="Мой плейлист">
///     <track youtube_id="dQw4w9WgXcQ" title="..." author="..."/>
/// </hoginote-playlist>
/// ```
class PlaylistIo {
  /// Бросает [FormatException]-подобное исключение при неверном XML.
  static ParsedXmlPlaylist parse(String xmlString) {
    late XmlDocument doc;
    try {
      doc = XmlDocument.parse(xmlString.trim());
    } catch (_) {
      throw const FormatException('Неверный формат XML');
    }

    final root = doc.rootElement;
    if (root.name.local != 'hoginote-playlist') {
      throw const FormatException('Неверный формат XML');
    }

    var name = root.getAttribute('name');
    if (name == null || name.trim().isEmpty) {
      name = 'Импортированный плейлист';
    }

    final entries = <XmlPlaylistEntry>[];
    for (final element in root.findElements('track')) {
      final youtubeId = element.getAttribute('youtube_id');
      if (youtubeId == null || youtubeId.isEmpty) continue;
      entries.add(XmlPlaylistEntry(
        youtubeId: youtubeId,
        title: element.getAttribute('title') ?? '',
        author: element.getAttribute('author') ?? '',
      ));
    }

    if (entries.isEmpty) {
      throw const FormatException('Неверный формат XML');
    }

    return ParsedXmlPlaylist(name: name, tracks: entries);
  }

  static String exportPlaylist(
    Playlist playlist,
    List<Track> tracks,
  ) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('hoginote-playlist', attributes: {'name': playlist.name},
        nest: () {
      for (final track in tracks) {
        builder.element('track', attributes: {
          'youtube_id': track.youtubeId,
          'title': track.title,
          'author': track.author,
        });
      }
    });
    return builder.buildDocument().toXmlString(pretty: true);
  }
}
