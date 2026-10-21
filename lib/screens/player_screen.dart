import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_handler.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';

/// Полноэкранный плеер в стиле Spotify (тёмно-бежевая тема).
///
/// Используется как контент bottom-sheet (с кнопкой «вниз»)
/// и как обычный экран.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 1,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          color: bgDark,
          child: Column(
            children: [
              // Кнопка «вниз» (свернуть) слева вверху.
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded,
                        size: 32, color: textSecondary),
                    tooltip: 'Свернуть',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Сейчас играет',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textSecondary.withOpacity(0.7),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  children: const [
                    _BigCover(),
                    SizedBox(height: 32),
                    _TrackInfo(),
                    SizedBox(height: 24),
                    _SeekBar(),
                    SizedBox(height: 8),
                    _ControlsRow(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Плеер без обёртки bottom-sheet — для использования внутри экрана.
class PlayerFullScreen extends StatelessWidget {
  const PlayerFullScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          _BigCover(),
          SizedBox(height: 32),
          _TrackInfo(),
          SizedBox(height: 24),
          _SeekBar(),
          SizedBox(height: 8),
          _ControlsRow(),
        ],
      ),
    );
  }
}

class _BigCover extends StatelessWidget {
  const _BigCover();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: bgCard,
          borderRadius: BorderRadius.circular(cardRadius * 2),
        ),
        child: const Icon(
          Icons.music_note_rounded,
          size: 96,
          color: accentBeige,
        ),
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  const _TrackInfo();

  @override
  Widget build(BuildContext context) {
    final track = context.select<AudioHandler, Track?>(
      (h) => h.currentTrack,
    );
    if (track == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: textPrimary,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          track.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: textSecondary,
            fontSize: 17,
          ),
        ),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar();

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final handler = context.read<AudioHandler>();
    return StreamBuilder<Duration>(
      stream: handler.positionStream,
      builder: (context, posSnap) {
        return StreamBuilder<Duration?>(
          stream: handler.durationStream,
          builder: (context, durSnap) {
            final position = posSnap.data ?? Duration.zero;
            final duration = durSnap.data ?? Duration.zero;
            final maxMs =
                duration.inMilliseconds > 0 ? duration.inMilliseconds : 1;
            final value = _dragValue != null
                ? _dragValue! * maxMs
                : position.inMilliseconds.toDouble().clamp(0.0, maxMs.toDouble());
            return Column(
              children: [
                Slider(
                  value: value.clamp(0.0, maxMs.toDouble()),
                  max: maxMs.toDouble(),
                  onChanged: (v) => setState(() => _dragValue = v / maxMs),
                  onChangeEnd: (v) {
                    handler.seek(Duration(milliseconds: v.round()));
                    setState(() => _dragValue = null);
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatDuration(position),
                        style: const TextStyle(
                            color: textSecondary, fontSize: 12),
                      ),
                      Text(
                        formatDuration(duration),
                        style: const TextStyle(
                            color: textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ControlsRow extends StatelessWidget {
  const _ControlsRow();

  @override
  Widget build(BuildContext context) {
    final handler = context.read<AudioHandler>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 28,
          color: textSecondary,
          tooltip: 'Предыдущий трек',
          onPressed: handler.previous,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        StreamBuilder<bool>(
          stream: handler.playingStream,
          initialData: handler.isPlaying,
          builder: (context, snapshot) {
            final playing = snapshot.data ?? false;
            return Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: accentBeige,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                iconSize: 40,
                color: bgDark,
                tooltip: playing ? 'Пауза' : 'Играть',
                onPressed: handler.togglePlay,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
            );
          },
        ),
        IconButton(
          iconSize: 28,
          color: textSecondary,
          tooltip: 'Следующий трек',
          onPressed: handler.next,
          icon: const Icon(Icons.skip_next_rounded),
        ),
      ],
    );
  }
}
