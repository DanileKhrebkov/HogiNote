import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/playlist.dart';
import '../models/track.dart';

/// Синглтон-помощник для работы с локальной SQLite-базой.
class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _dbName = 'hoginote.db';
  static const _dbVersion = 1;

  Database? _database;

  Future<Database> get database async {
    _database ??= await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE tracks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            youtube_id TEXT NOT NULL UNIQUE,
            title TEXT NOT NULL,
            author TEXT NOT NULL,
            duration_ms INTEGER NOT NULL,
            file_path TEXT NOT NULL,
            downloaded_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlists (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE playlist_tracks (
            playlist_id INTEGER NOT NULL,
            track_id INTEGER NOT NULL,
            position INTEGER NOT NULL,
            PRIMARY KEY (playlist_id, track_id),
            FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
            FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX idx_tracks_title ON tracks(title)');
        await db.execute('CREATE INDEX idx_tracks_author ON tracks(author)');
      },
    );
  }

  /// Папка, в которой хранятся скачанные аудиофайлы.
  Future<Directory> downloadsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, 'downloads'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  // ---------------------------------------------------------------------------
  // Треки
  // ---------------------------------------------------------------------------

  /// Вставка трека. Дубликаты по [Track.youtubeId] игнорируются.
  /// Возвращает id записи (или id существующей).
  Future<int> insertTrack(Track track) async {
    final db = await database;
    return db.insert(
      'tracks',
      track.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<Track>> getAllTracks() async {
    final db = await database;
    final rows = await db.query('tracks', orderBy: 'downloaded_at DESC');
    return rows.map(Track.fromMap).toList();
  }

  Future<Track?> getTrackByYoutubeId(String id) async {
    final db = await database;
    final rows = await db
        .query('tracks', where: 'youtube_id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Track.fromMap(rows.first);
  }

  /// Удаляет трек из БД (каскадно из плейлистов) и файл с диска.
  Future<void> deleteTrack(int id) async {
    final db = await database;
    final rows =
        await db.query('tracks', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isNotEmpty) {
      final filePath = rows.first['file_path'] as String;
      await _deleteFileQuietly(filePath);
    }
    await db.delete('tracks', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // Плейлисты
  // ---------------------------------------------------------------------------

  Future<int> createPlaylist(String name) async {
    final db = await database;
    return db.insert('playlists', Playlist(
      name: name,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ).toMap());
  }

  Future<List<Playlist>> getAllPlaylists() async {
    final db = await database;
    final rows = await db.query('playlists', orderBy: 'created_at DESC');
    return rows.map(Playlist.fromMap).toList();
  }

  Future<void> renamePlaylist(int playlistId, String newName) async {
    final db = await database;
    await db.update(
      'playlists',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [playlistId],
    );
  }

  Future<void> deletePlaylist(int playlistId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('playlist_tracks',
          where: 'playlist_id = ?', whereArgs: [playlistId]);
      await txn.delete('playlists', where: 'id = ?', whereArgs: [playlistId]);
    });
  }

  Future<List<Track>> getTracksForPlaylist(int playlistId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT t.* FROM tracks t
      JOIN playlist_tracks pt ON pt.track_id = t.id
      WHERE pt.playlist_id = ?
      ORDER BY pt.position ASC
      ''',
      [playlistId],
    );
    return rows.map(Track.fromMap).toList();
  }

  /// Добавляет трек в плейлист на позицию `max + 1`.
  Future<void> addTrackToPlaylist(int playlistId, int trackId) async {
    final db = await database;
    final existing = await db.query(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
      limit: 1,
    );
    if (existing.isNotEmpty) return; // уже в плейлисте
    final maxRows = await db.query(
      'playlist_tracks',
      columns: ['MAX(position) AS max_pos'],
      where: 'playlist_id = ?',
      whereArgs: [playlistId],
    );
    final maxPos = (maxRows.first['max_pos'] as int?) ?? -1;
    await db.insert('playlist_tracks', {
      'playlist_id': playlistId,
      'track_id': trackId,
      'position': maxPos + 1,
    });
  }

  /// Убирает трек из плейлиста (файл на диске НЕ удаляется).
  Future<void> removeTrackFromPlaylist(int playlistId, int trackId) async {
    final db = await database;
    await db.delete(
      'playlist_tracks',
      where: 'playlist_id = ? AND track_id = ?',
      whereArgs: [playlistId, trackId],
    );
  }

  Future<int> countTracksInPlaylist(int playlistId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM playlist_tracks WHERE playlist_id = ?',
      [playlistId],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Очистка
  // ---------------------------------------------------------------------------

  /// Удаляет все записи из всех таблиц и все скачанные файлы с диска.
  Future<void> clearAll() async {
    final db = await database;
    final rows = await db.query('tracks', columns: ['file_path']);
    await db.delete('playlist_tracks');
    await db.delete('playlists');
    await db.delete('tracks');
    for (final row in rows) {
      await _deleteFileQuietly(row['file_path'] as String);
    }
    // На случай «осиротевших» файлов — вычищаем всю папку загрузок.
    final dir = await downloadsDirectory();
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is File) {
          await _deleteFileQuietly(entity.path);
        }
      }
    }
  }

  Future<void> _deleteFileQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Файл мог быть уже удалён — молча пропускаем.
    }
  }
}
