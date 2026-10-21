import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_handler.dart';
import '../theme/app_theme.dart';
import 'cover_placeholder.dart';
import 'player_overlay.dart';

/// Тонкая полоса с текущим треком над нижней навигацией.
/// Показывается только если есть активный трек.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AudioHandler>(
      builder: (context, handler, _) {
        final track = handler.currentTrack;
        if (track == null) return const SizedBox.shrink();

        return Material(
          color: bgCard,
          child: SafeArea(
            top: false,
            child: InkWell(
              onTap: () => showPlayerOverlay(context),
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: CoverPlaceholder(size: 44),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            track.author,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    StreamBuilder<bool>(
                      stream: handler.playingStream,
                      initialData: handler.isPlaying,
                      builder: (context, snapshot) {
                        final playing = snapshot.data ?? false;
                        return IconButton(
                          iconSize: 32,
                          icon: Icon(
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: accentBeige,
                          ),
                          onPressed: handler.togglePlay,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.expand_less_rounded,
                          color: textSecondary),
                      onPressed: () => showPlayerOverlay(context),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
