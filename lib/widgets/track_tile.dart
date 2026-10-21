import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_handler.dart';
import '../models/track.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';
import 'cover_placeholder.dart';

/// Строка трека в списках (поиск / библиотека / плейлист).
///
/// - [onTap] — действие по тапу (скачать / играть);
/// - [onLongPress] — контекстное меню.
class TrackTile extends StatelessWidget {
  final String title;
  final String author;
  final Duration duration;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool isCurrentTrack;

  const TrackTile({
    super.key,
    required this.title,
    required this.author,
    required this.duration,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.isCurrentTrack = false,
  });

  factory TrackTile.fromSearchResult(
    SearchResultItem item, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    Widget? trailing,
  }) =>
      TrackTile(
        title: item.title,
        author: item.author,
        duration: item.duration,
        onTap: onTap,
        onLongPress: onLongPress,
        trailing: trailing,
      );

  factory TrackTile.fromTrack(
    BuildContext context,
    Track track, {
    VoidCallback? onTap,
    VoidCallback? onLongPress,
    Widget? trailing,
  }) {
    final handler = context.read<AudioHandler>();
    return TrackTile(
      title: track.title,
      author: track.author,
      duration: track.duration,
      onTap: onTap,
      onLongPress: onLongPress,
      trailing: trailing,
      isCurrentTrack: handler.currentTrack?.id == track.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      leading: isCurrentTrack
          ? const CoverPlaceholder(icon: Icons.graphic_eq_rounded)
          : const CoverPlaceholder(),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrentTrack ? accentBeige : textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        author,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: textSecondary),
      ),
      trailing: trailing ??
          Text(
            formatDuration(duration),
            style: const TextStyle(color: textSecondary),
          ),
    );
  }
}
