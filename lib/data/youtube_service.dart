import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/track.dart';

/// Пользовательская ошибка: наружу отдаём только человекочитаемое сообщение,
/// никогда — stack trace или технические детали YouTube.
class YoutubeFailure implements Exception {
  final String userMessage;

  const YoutubeFailure(this.userMessage);

  @override
  String toString() => userMessage;
}

const kSourceUnavailableMessage =
    'Источник недоступен. Проверьте наличие новой версии на '
    'github.com/DanileKhrebkov/HogiNote/releases';

/// Обёртка над `youtube_explode_dart`: поиск и скачивание аудио.
class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  static final _watchUrlRegExp = RegExp(
    r'(?:youtube\.com/watch\?(?:.*&)?v=|youtu\.be/)([A-Za-z0-9_-]{11})',
  );

  /// Извлекает videoId из ссылки YouTube или из «голого» id.
  String? extractVideoId(String input) {
    final trimmed = input.trim();
    final match = _watchUrlRegExp.firstMatch(trimmed);
    if (match != null) return match.group(1);
    return VideoId.parseVideoId(trimmed);
  }

  bool looksLikeUrl(String input) =>
      input.contains('youtube.com') || input.contains('youtu.be');

  /// Поиск по названию/автору либо получение метаданных по ссылке.
  Future<List<SearchResultItem>> search(String query) async {
    try {
      final videoId = extractVideoId(query);
      if (videoId != null && (looksLikeUrl(query) || query.trim().length == 11)) {
        final video = await _yt.videos.get(videoId);
        return [_fromVideo(video.id.value, video)];
      }

      final results = await _yt.search.search(query);
      return results
          .where((v) => v.type == VideoType.video)
          .map((v) => _fromVideo(v.id.value, v))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('[YoutubeService.search] $e');
      throw const YoutubeFailure(kSourceUnavailableMessage);
    }
  }

  SearchResultItem _fromVideo(String id, Video video) => SearchResultItem(
        videoId: id,
        title: video.title,
        author: video.author,
        duration: video.duration ?? Duration.zero,
      );

  /// Скачивает аудио лучшего качества в [saveDir].
  /// Возвращает путь к сохранённому файлу.
  Future<String> downloadAudio(
    String videoId,
    String saveDir, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final manifest =
          await _yt.videos.streams.getManifest(VideoId(videoId));
      final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
      final stream = _yt.videos.streams.get(audioStreamInfo);

      final filePath = '$saveDir/$videoId.m4a';
      final file = File(filePath);
      final fileStream = file.openWrite();

      final totalBytes = audioStreamInfo.size.totalBytes;
      var downloadedBytes = 0;

      try {
        await for (final chunk in stream) {
          downloadedBytes += chunk.length;
          fileStream.add(chunk);
          if (totalBytes > 0) {
            onProgress?.call(downloadedBytes / totalBytes);
          }
        }
        await fileStream.flush();
      } finally {
        await fileStream.close();
      }

      onProgress?.call(1.0);
      return filePath;
    } catch (e) {
      if (kDebugMode) debugPrint('[YoutubeService.downloadAudio] $e');
      throw const YoutubeFailure('Ошибка скачивания. Попробуйте позже.');
    }
  }

  void dispose() => _yt.close();
}
