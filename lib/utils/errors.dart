import 'package:flutter/foundation.dart';

/// Единое сообщение об ошибке источника (по ТЗ, Модуль 5.2 / 7).
const String sourceUnavailableMessage =
    'Источник недоступен. Проверьте наличие новой версии на '
    'github.com/DanileKhrebkov/HogiNote/releases';

/// URL страницы релизов для кнопки «Проверить обновления».
const String releasesUrl =
    'https://github.com/DanileKhrebkov/HogiNote/releases';

/// Превращает любое исключение в пользовательскую строку.
/// Никогда не возвращает stack trace или технические детали.
String userErrorMessage(Object error) {
  if (error is YoutubeUserError) return error.message;
  if (error is FormatException) return error.message;
  return sourceUnavailableMessage;
}

/// Простая пользовательская ошибка с готовым текстом.
class YoutubeUserError implements Exception {
  final String message;

  const YoutubeUserError(this.message);

  @override
  String toString() {
    if (kDebugMode) return 'YoutubeUserError: $message';
    return message;
  }
}

/// Форматирование длительности в `mm:ss`.
String formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) {
    return '${d.inHours}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
