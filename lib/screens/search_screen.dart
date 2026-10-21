import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio/audio_handler.dart';
import '../data/database_helper.dart';
import '../data/youtube_service.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../widgets/download_button.dart';
import '../widgets/track_tile.dart';

/// Экран «Поиск»: строка ввода + результаты (или ссылка на YouTube).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

enum _SearchStatus { empty, loading, results, error }

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final YoutubeService _service = YoutubeService();

  _SearchStatus _status = _SearchStatus.empty;
  List<SearchResultItem> _results = [];
  Set<String> _downloadedIds = {};
  String? _errorMessage;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _refreshDownloaded();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _refreshDownloaded() async {
    final tracks = await DatabaseHelper.instance.getAllTracks();
    if (!mounted) return;
    setState(() {
      _downloadedIds = tracks.map((t) => t.youtubeId).toSet();
    });
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _status = _SearchStatus.empty;
        _results = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () {
      if (value == _controller.text) _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _status = _SearchStatus.loading);
    try {
      final results = await _service.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _status =
            results.isEmpty ? _SearchStatus.error : _SearchStatus.results;
        if (results.isEmpty) {
          _errorMessage = null; // пустой результат — не ошибка источника
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _SearchStatus.error;
        _errorMessage = userErrorMessage(e);
      });
    }
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _status = _SearchStatus.empty;
      _results = [];
      _errorMessage = null;
    });
  }

  Future<void> _openReleases() async {
    final uri = Uri.parse(releasesUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть браузер')),
      );
    }
  }

  /// Тап по результату: если скачан — играем, иначе — ничего (качаем кнопкой).
  Future<void> _onTileTap(SearchResultItem item) async {
    if (!_downloadedIds.contains(item.videoId)) return;
    final track =
        await DatabaseHelper.instance.getTrackByYoutubeId(item.videoId);
    if (track == null) return;
    final all = await DatabaseHelper.instance.getAllTracks();
    final index = all.indexWhere((t) => t.id == track.id);
    await context.read<AudioHandler>().setQueue(
          all,
          startIndex: index < 0 ? 0 : index,
        );
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const _PlayerHost(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              onSubmitted: _performSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Название, автор или ссылка YouTube',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: textSecondary),
                suffixIcon: _status == _SearchStatus.empty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: textSecondary),
                        tooltip: 'Очистить',
                        onPressed: _clear,
                      ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _SearchStatus.empty:
        return const Center(
          child: Text(
            'Введите название, автора или ссылку',
            style: TextStyle(color: textSecondary),
          ),
        );
      case _SearchStatus.loading:
        return const Center(
          child: CircularProgressIndicator(color: accentBeige),
        );
      case _SearchStatus.error:
        return _buildErrorOrEmpty();
      case _SearchStatus.results:
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: _results.length,
          itemBuilder: (context, i) {
            final item = _results[i];
            final downloaded = _downloadedIds.contains(item.videoId);
            return TrackTile.fromSearchResult(
              item,
              onTap: () => _onTileTap(item),
              trailing: DownloadButton(
                key: ValueKey('dl_${item.videoId}'),
                item: item,
                alreadyDownloaded: downloaded,
                onDownloaded: () {
                  setState(() => _downloadedIds.add(item.videoId));
                },
              ),
            );
          },
        );
    }
  }

  Widget _buildErrorOrEmpty() {
    final isSourceError = _errorMessage != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSourceError ? Icons.cloud_off_rounded : Icons.search_off_rounded,
              size: 48,
              color: textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              isSourceError
                  ? _errorMessage!
                  : 'Ничего не найдено',
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary),
            ),
            if (isSourceError) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _openReleases,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Проверить обновления'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: accentBeige,
                  side: const BorderSide(color: accentBeige),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(cardRadius),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Простая обёртка, чтобы открыть полноэкранный плеер как обычный экран.
class _PlayerHost extends StatelessWidget {
  const _PlayerHost();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
        child: Consumer<AudioHandler>(
          builder: (_, handler, __) {
            final Track? track = handler.currentTrack;
            if (track == null) {
              return const SizedBox.shrink();
            }
            return const PlayerFullScreen();
          },
        ),
      ),
    );
  }
}
