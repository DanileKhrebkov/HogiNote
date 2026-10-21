import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../audio/audio_handler.dart';
import '../data/database_helper.dart';
import '../data/youtube_service.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/playlist_io.dart';
import '../widgets/track_tile.dart';
import 'playlist_screen.dart';

/// Экран «Библиотека»: вкладки «Все треки» и «Плейлисты».
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<Track> _tracks = [];
  List<Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final db = DatabaseHelper.instance;
    final tracks = await db.getAllTracks();
    final playlists = await db.getAllPlaylists();
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _playlists = playlists;
      _loading = false;
    });
  }

  Future<void> _playFrom(List<Track> queue, int index) async {
    if (queue.isEmpty) return;
    await context.read<AudioHandler>().setQueue(queue, startIndex: index);
  }

  Future<void> _showTrackMenu(Track track) async {
    final db = DatabaseHelper.instance;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded,
                    color: accentBeige),
                title: const Text('Добавить в плейлист'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _addTrackToPlaylistDialog(track);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                title: const Text('Удалить',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Удалить трек?'),
                      content: Text(
                        '«${track.title}» будет удалён из библиотеки '
                        'и с диска.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Отмена'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            'Удалить',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && track.id != null) {
                    await db.deleteTrack(track.id!);
                    await _refresh();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addTrackToPlaylistDialog(Track track) async {
    final db = DatabaseHelper.instance;
    final playlists = await db.getAllPlaylists();
    if (!mounted) return;

    if (playlists.isEmpty) {
      // Нет плейлистов — предложим создать.
      final name = await _promptPlaylistName(title: 'Новый плейлист');
      if (name == null || name.trim().isEmpty) return;
      final id = await db.createPlaylist(name.trim());
      if (track.id != null) {
        await db.addTrackToPlaylist(id, track.id!);
      }
      await _refresh();
      return;
    }

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(cardRadius)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Выберите плейлист',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final pl in playlists)
                    ListTile(
                      leading: const Icon(Icons.queue_music_rounded,
                          color: accentBeige),
                      title: Text(pl.name),
                      onTap: () => Navigator.pop(sheetContext, pl.id),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add_rounded, color: accentBeige),
                    title: const Text('Создать новый плейлист'),
                    onTap: () => Navigator.pop(sheetContext, -1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    int playlistId = selected;
    if (selected == -1) {
      final name = await _promptPlaylistName(title: 'Новый плейлист');
      if (name == null || name.trim().isEmpty) return;
      playlistId = await db.createPlaylist(name.trim());
    }
    if (track.id != null) {
      await db.addTrackToPlaylist(playlistId, track.id!);
    }
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Добавлено в плейлист')),
    );
  }

  Future<String?> _promptPlaylistName({String title = 'Новый плейлист'}) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('ОК'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Библиотека'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Все треки'),
              Tab(text: 'Плейлисты'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: accentBeige))
            : TabBarView(
                controller: _tabController,
                children: [_buildAllTracks(), _buildPlaylists()],
              ),
      ),
    );
  }

  Widget _buildAllTracks() {
    if (_tracks.isEmpty) {
      return const _EmptyState(
        icon: Icons.library_music_outlined,
        text: 'Скачайте первый трек во вкладке Поиск',
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      color: accentBeige,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _tracks.length,
        itemBuilder: (context, i) {
          final track = _tracks[i];
          return TrackTile.fromTrack(
            context,
            track,
            onTap: () => _playFrom(_tracks, i),
            onLongPress: () => _showTrackMenu(track),
            trailing: Text(
              formatDuration(track.duration),
              style: const TextStyle(color: textSecondary),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaylists() {
    return Consumer<AudioHandler>(
      builder: (context, _, __) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _createPlaylist,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Создать'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentBeige,
                      side: const BorderSide(color: accentBeige),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cardRadius),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _importFromClipboard,
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: const Text('Вставить XML'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentBeige,
                      side: const BorderSide(color: textSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cardRadius),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_playlists.isEmpty)
            const Expanded(
              child: _EmptyState(
                icon: Icons.playlist_play_rounded,
                text: 'Нет плейлистов. Создайте или вставьте из XML',
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: _playlists.length,
                itemBuilder: (context, i) {
                  final pl = _playlists[i];
                  return FutureBuilder<int>(
                    future: DatabaseHelper.instance
                        .countTracksInPlaylist(pl.id!),
                    builder: (context, snap) {
                      final count = snap.data ?? 0;
                      return ListTile(
                        leading: const CoverIcon(),
                        title: Text(pl.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          '$count треков · ${_formatDate(pl.createdDate)}',
                          style: const TextStyle(color: textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded,
                            color: textSecondary),
                        onTap: () async {
                          await Navigator.of(context)
                              .push(MaterialPageRoute<void>(
                            builder: (_) => PlaylistScreen(
                              playlist: pl,
                              onChanged: _refresh,
                            ),
                          ));
                          _refresh();
                        },
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createPlaylist() async {
    final name = await _promptPlaylistName(title: 'Новый плейлист');
    if (name == null || name.trim().isEmpty) return;
    await DatabaseHelper.instance.createPlaylist(name.trim());
    await _refresh();
  }

  /// Модуль 6: импорт плейлиста из XML (вставка из буфера или вручную).
  Future<void> _importFromClipboard() async {
    final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
    final controller = TextEditingController(
      text: (clipboard?.text ?? '').contains('hoginote-playlist')
          ? clipboard!.text
          : '',
    );

    final xmlInput = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Вставить плейлист (XML)'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: '<hoginote-playlist name="...">...</hoginote-playlist>',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Импортировать'),
          ),
        ],
      ),
    );

    if (xmlInput == null || xmlInput.trim().isEmpty) return;

    late final ParsedXmlPlaylist parsed;
    try {
      parsed = PlaylistIo.parse(xmlInput);
    } on FormatException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный формат XML')),
      );
      return;
    }

    final db = DatabaseHelper.instance;
    final service = YoutubeService();
    final dir = await db.downloadsDirectory();
    final playlistId = await db.createPlaylist(parsed.name);

    var done = 0;
    var failed = 0;
    final total = parsed.tracks.length;

    // Прогресс-диалог, не блокирующий UI-поток.
    _progressDone = 0;
    _progressTotal = total;
    unawaited(_showProgressDialog());

    for (final entry in parsed.tracks) {
      try {
        var track = await db.getTrackByYoutubeId(entry.youtubeId);
        if (track == null) {
          final filePath = await service.downloadAudio(
            entry.youtubeId,
            dir.path,
          );
          final newTrack = Track(
            youtubeId: entry.youtubeId,
            title: entry.title.isNotEmpty
                ? entry.title
                : entry.youtubeId,
            author: entry.author,
            durationMs: 0,
            filePath: filePath,
            downloadedAt: DateTime.now().millisecondsSinceEpoch,
          );
          final id = await db.insertTrack(newTrack);
          track = (await db.getTrackByYoutubeId(entry.youtubeId)) ??
              newTrack.copyWith(id: id);
        }
        if (track.id != null) {
          await db.addTrackToPlaylist(playlistId, track.id!);
        }
        done++;
      } catch (_) {
        failed++;
      }
      _updateProgress(done, total);
    }

    service.dispose();
    _hideProgressDialog();
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Импортировано $done из $total. '
          '$failed треков не удалось скачать.',
        ),
      ),
    );
  }

  // --- прогресс-диалог импорта ---------------------------------------------

  int _progressDone = 0;
  int _progressTotal = 0;
  final ValueNotifier<String> _progressText = ValueNotifier('Импорт: 0/0');

  Future<void> _showProgressDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Импорт плейлиста'),
        content: ValueListenableBuilder<String>(
          valueListenable: _progressText,
          builder: (_, text, __) => Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: accentBeige,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(text)),
            ],
          ),
        ),
      ),
    );
  }

  void _updateProgress(int done, int total) {
    _progressDone = done;
    _progressTotal = total;
    _progressText.value = 'Импорт: $done/$total треков';
  }

  void _hideProgressDialog() {
    _progressText.value = 'Готово: $_progressDone/$_progressTotal';
    Navigator.of(context, rootNavigator: true).pop();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.year}';
}

class CoverIcon extends StatelessWidget {
  const CoverIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: const Icon(Icons.queue_music_rounded, color: accentBeige),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: textSecondary),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: textSecondary),
          ),
        ],
      ),
    );
  }
}
