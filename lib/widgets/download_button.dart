import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/database_helper.dart';
import '../data/youtube_service.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';

/// Кнопка скачивания трека из результатов поиска.
///
/// Состояния:
/// - свободна (иконка «скачать»),
/// - скачивается (круговой индикатор с прогрессом 0..1),
/// - уже скачано (галочка).
class DownloadButton extends StatefulWidget {
  final SearchResultItem item;
  final bool alreadyDownloaded;

  /// Вызывается после успешного добавления трека в БД.
  final VoidCallback? onDownloaded;

  const DownloadButton({
    super.key,
    required this.item,
    this.alreadyDownloaded = false,
    this.onDownloaded,
  });

  @override
  State<DownloadButton> createState() => _DownloadButtonState();
}

enum _Status { idle, downloading, done }

class _DownloadButtonState extends State<DownloadButton> {
  _Status _status = _Status.idle;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    if (widget.alreadyDownloaded) _status = _Status.done;
  }

  @override
  void didUpdateWidget(covariant DownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.alreadyDownloaded && _status == _Status.idle) {
      _status = _Status.done;
    }
  }

  Future<void> _download() async {
    if (_status == _Status.downloading) return;

    final db = DatabaseHelper.instance;
    final service = context.read<YoutubeService>();
    final messenger = ScaffoldMessenger.of(context);

    // Проверка дубликата по youtube_id.
    final existing = await db.getTrackByYoutubeId(widget.item.videoId);
    if (existing != null) {
      if (!mounted) return;
      setState(() => _status = _Status.done);
      messenger.showSnackBar(
        const SnackBar(content: Text('Уже скачано')),
      );
      return;
    }

    setState(() {
      _status = _Status.downloading;
      _progress = 0;
    });

    try {
      final dir = await db.downloadsDirectory();
      final filePath = await service.downloadAudio(
        widget.item.videoId,
        dir.path,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p.clamp(0.0, 1.0));
        },
      );

      final track = Track(
        youtubeId: widget.item.videoId,
        title: widget.item.title,
        author: widget.item.author,
        durationMs: widget.item.duration.inMilliseconds,
        filePath: filePath,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
      );
      await db.insertTrack(track);

      if (!mounted) return;
      setState(() => _status = _Status.done);
      messenger.showSnackBar(
        SnackBar(content: Text('Скачано: ${widget.item.title}')),
      );
      widget.onDownloaded?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = _Status.idle);
      messenger.showSnackBar(
        SnackBar(content: Text(userErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _Status.done:
        return const Icon(Icons.check_circle_rounded,
            color: accentBeige, semanticLabel: 'Уже скачано');
      case _Status.downloading:
        return SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            value: _progress > 0 ? _progress : null,
            strokeWidth: 3,
            color: accentBeige,
          ),
        );
      case _Status.idle:
        return IconButton(
          icon: const Icon(Icons.download_rounded, color: textSecondary),
          tooltip: 'Скачать',
          onPressed: _download,
        );
    }
  }
}
