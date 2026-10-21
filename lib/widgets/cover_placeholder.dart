import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Квадратная обложка-заглушка: иконка ноты на фоне `bgCard`.
class CoverPlaceholder extends StatelessWidget {
  final double size;
  final IconData icon;

  const CoverPlaceholder({
    super.key,
    this.size = 56,
    this.icon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(cardRadius),
      ),
      child: Icon(
        icon,
        size: size * 0.45,
        color: accentBeige.withOpacity(0.7),
      ),
    );
  }
}
