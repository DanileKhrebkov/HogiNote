import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../audio/audio_handler.dart';
import '../data/database_helper.dart';
import '../models/playlist.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import '../utils/playlist_io.dart';
import '../widgets/track_tile.dart';

/// Экран одного плейлиста.
class PlaylistScreen extends StatefulWidget {
  final Playlist playlist;
  final VoidCallback? onChanged;

  const PlaylistScreen({super.key, required this.playlist, this.onChanged});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  late Playlist _playlist = widget.playlist;
  List<Track> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final db = DatabaseHelper.instance;
    final tracks = await db.getTracksForPlaylist(_playlist.id!);
    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _loading = false;
    });
    widget.onChanged?.call();
  }

  Future<void> _playAll() async {
    if (_tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('В плейлисте нет треков')),
      );
      return;
    }
    await context.read<AudioHandler>().setQueue(_tracks, startIndex: 0);
  }

  Future<void> _rename() async {
    final controller = TextEditingController(text: _playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Переименовать плейлист'),
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
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty) return;
    await DatabaseHelper.instance.renamePlaylist(_playlist.id!, name.trim());
    setState(() {
      _playlist = Playlist(
        id: _playlist.id,
        name: name.trim(),
        createdAt: _playlist.createdAt,
      );
    });
    widget.onChanged?.call();
  }

  Future<void> _deletePlaylist() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить плейлист?'),
        content: Text('«${_playlist.name}» будет удалён. Треки останутся в библиотеке.'),
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
    if (confirmed != true) return;
    await DatabaseHelper.instance.deletePlaylist(_playlist.id!);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _exportXml() async {
    final xmlString = PlaylistIo.exportPlaylist(_playlist, _tracks);
    await Clipboard.setData(ClipboardData(text: xmlString));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('XML скопирован в буфер обмена')),
    );
  }

  /// Диалог выбора скачанных треков с чекбоксами.
  Future<void> _addTracks() async {
    final db = DatabaseHelper.instance;
    final all = await db.getAllTracks();
    final existingIds = _tracks.map((t) => t.id).toSet();
    final selectable = all.where((t) => !existingIds.contains(t.id)).toList();

    if (selectable.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все треки уже в плейлисте')),
      );
      return;
    }

    final selected = <int>{};
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Добавить треки'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: selectable.length,
              itemBuilder: (_, i) {
                final t = selectable[i];
                return CheckboxListTile(
                  value: selected.contains(t.id),
                  activeColor: accentBeige,
                  title: Text(t.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(t.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: textSecondary)),
                  onChanged: (v) => setDialogState(() {
                    if (v == true) {
                      selected.add(t.id!);
                    } else {
                      selected.remove(t.id);
                    }
                  }),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    for (final trackId in selected) {
      await db.addTrackToPlaylist(_playlist.id!, trackId);
    }
    await _refresh();
  }

  Future<void> _removeTrack(Track track) async {
    await DatabaseHelper.instance
        .removeTrackFromPlaylist(_playlist.id!, track.id!);
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Удалено из плейлиста')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _playlist.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Играть всё',
            icon: const Icon(Icons.play_circle_outline_rounded),
            onPressed: _playAll,
          ),
          PopupMenuButton<String>(
            tooltip: 'Меню',
            icon: const Icon(Icons.more_vert_rounded, color: textSecondary),
            onSelected: (value) {
              switch (value) {
                case 'add':
                  _addTracks();
                  break;
                case 'rename':
                  _rename();
                  break;
                case 'export':
                  _exportXml();
                  break;
                case 'delete':
                  _deletePlaylist();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'add',
                child: Text('Добавить треки'),
              ),
              PopupMenuItem(
                value: 'export',
                child: Text('Экспортировать в XML'),
              ),
              PopupMenuItem(
                value: 'rename',
                child: Text('Переименовать'),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Удалить плейлист',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accentBeige))
          : _tracks.isEmpty
              ? const Center(
                  child: Text(
                    'Плейлист пуст. Нажмите «⋮» → «Добавить треки»',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSecondary),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: _tracks.length,
                  onReorder: (oldIndex, newIndex) async {
                    // Простое решение: пересобираем связи через add/remove.
                    setState(() {
                      final item = _tracks.removeAt(oldIndex);
                      if (newIndex > oldIndex) newIndex--;
                      _tracks.insert(newIndex, item);
                    });
                    final db = DatabaseHelper.instance;
                    for (var i = 0; i < _tracks.length; i++) {
                      await db.removeTrackFromPlaylist(
                          _playlist.id!, _tracks[i].id!);
                    }
                    for (final t in _tracks) {
                      await db.addTrackToPlaylist(_playlist.id!, t.id!);
                    }
                  },
                  itemBuilder: (context, i) {
                    final track = _tracks[i];
                    return Dismissible(
                      key: ValueKey('pl_${_playlist.id}_${track.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Colors.redAccent.withOpacity(0.15),
                        child: const Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent),
                      ),
                      onDismissed: (_) => _removeTrack(track),
                      child: TrackTile.fromTrack(
                        context,
                        track,
                        onTap: () => context
                            .read<AudioHandler>()
                            .setQueue(_tracks, startIndex: i),
                        trailing: Text(
                          formatDuration(track.duration),
                          style: const TextStyle(color: textSecondary),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
