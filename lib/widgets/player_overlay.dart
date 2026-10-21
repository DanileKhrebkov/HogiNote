import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_handler.dart';
import '../screens/player_screen.dart';

/// Открывает полноэкранный плеер поверх текущего экрана.
Future<void> showPlayerOverlay(BuildContext context) {
  final handler = context.read<AudioHandler>();
  if (handler.currentTrack == null) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PlayerScreen(),
  );
}
