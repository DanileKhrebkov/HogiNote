import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../models/track.dart';

/// Аудио-движок поверх `just_audio` + `just_audio_background`.
/// Очередь = список треков (вся библиотека или плейлист).
class AudioHandler extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  List<Track> _queue = [];
  int _currentIndex = -1;

  List<Track> get queue => List.unmodifiable(_queue);
  int get currentIndex => _currentIndex;
  Track? get currentTrack =>
      (_currentIndex >= 0 && _currentIndex < _queue.length)
          ? _queue[_currentIndex]
          : null;

  bool get isPlaying => _player.playing;
  bool get isPlayingAny => _player.playerState.playing;

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    if (tracks.isEmpty) return;
    _queue = List.of(tracks);
    _currentIndex = startIndex.clamp(0, _queue.length - 1);
    await _loadCurrent();
    notifyListeners();
  }

  Future<void> _loadCurrent() async {
    final track = currentTrack;
    if (track == null) return;
    await _player.setAudioSource(
      AudioSource.file(
        track.filePath,
        tag: MediaItem(
          // Уникальный id внутри уведомления.
          id: '${track.id ?? track.youtubeId}',
          title: track.title,
          artist: track.author,
          duration: track.duration,
        ),
      ),
    );
    await _player.play();
  }

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> togglePlay() =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> next() async {
    if (_queue.isEmpty) return;
    _currentIndex = (_currentIndex + 1) % _queue.length;
    await _loadCurrent();
    notifyListeners();
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    // Как в обычных плеерах: если уже играем больше 3 секунд —
    // перемотать в начало текущего трека, иначе — предыдущий.
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    _currentIndex =
        (_currentIndex - 1 + _queue.length) % _queue.length;
    await _loadCurrent();
    notifyListeners();
  }

  /// Автопереход к следующему треку по окончании текущего.
  void listenToCompletion() {
    _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        next();
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
}
