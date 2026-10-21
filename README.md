# Hoginote

Офлайн-плеер для музыки из YouTube. Без регистрации. Без сбора данных.

Вся логика и все данные — на устройстве пользователя. Серверной части нет.

## Возможности

- 🔍 **Поиск треков на YouTube** — по названию, автору или прямой ссылке (`youtube.com/watch`, `youtu.be`)
- ⬇️ **Скачивание аудио** для офлайн-прослушивания (хранится в приватной папке приложения)
- 🎧 **Фоновое воспроизведение** с управлением из уведомления (Android foreground service / iOS background audio)
- 📚 **Локальная библиотека** треков и плейлистов
- 🗂️ **Плейлисты**: создание, переименование, drag-and-drop сортировка, добавление/удаление треков
- 📋 **Импорт/экспорт плейлистов в XML** (через буфер обмена)
- 🌙 **Тёмная тема** в бежевых тонах (Material 3)
- 🖥️ Единая кодовая база Flutter: Android, iOS, Desktop (структура готова; MVP проверен на Android)

## Интерфейс

Приложение состоит из трёх вкладок (BottomNavigationBar на мобильных, NavigationRail на desktop):

1. **Поиск** — строка ввода, список результатов, кнопка скачивания с круговым прогрессом
2. **Библиотека** — вкладки «Все треки» и «Плейлисты», long-press меню (добавить в плейлист / удалить)
3. **Настройки** — «О приложении», проверка обновлений, «Очистить всё скачанное»

Дополнительно: полноэкранный плеер в стиле Spotify и mini-player внизу экрана.

## Требования для сборки

- Flutter SDK (stable, >= 3.10)
- Android SDK (для Android-сборки), `minSdkVersion 21`
- Xcode (для iOS, только macOS)

## Сборка

```bash
git clone https://github.com/DanileKhrebkov/HogiNote.git
cd HogiNote
flutter pub get
flutter analyze
flutter test
flutter build apk --release   # Android
flutter build ios --release   # iOS (только на macOS)
```

APK будет в `build/app/outputs/flutter-apk/app-release.apk`.

Подробнее о настройке платформ (AndroidManifest, Info.plist, разрешения) — в [docs/BUILD.md](docs/BUILD.md).

### Подпись APK (для GitHub Releases)

Следуйте официальной инструкции Flutter:
https://docs.flutter.dev/deployment/android#signing-the-app

## Разрешения приложения

Hoginote запрашивает у ОС минимально необходимые разрешения:

| Разрешение | Платформа | Зачем |
|---|---|---|
| `INTERNET` | Android | Поиск и скачивание аудио с YouTube |
| `WAKE_LOCK` | Android | Не засыпать во время воспроизведения |
| `FOREGROUND_SERVICE` | Android | Фоновое воспроизведение |
| `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Android (API 34+) | Медиа-сервис в соответствии с политикой Google |
| `UIBackgroundModes: audio` | iOS | Фоновое воспроизведение |

**Приватность:** приложение не собирает, не хранит на серверах и не передаёт никаких персональных данных. Нет аналитики, трекинга и телеметрии. Все треки, плейлисты и БД (SQLite) хранятся только локально и удаляются вместе с данными приложения.

## Структура проекта

```
lib/
├── main.dart            # инициализация, JustAudioBackground
├── app.dart             # MaterialApp, навигация, provider'ы
├── theme/app_theme.dart # тёмная бежевая тема Material 3
├── models/              # Track, Playlist, SearchResultItem
├── data/                # DatabaseHelper (SQLite), YoutubeService
├── audio/               # AudioHandler (очередь, just_audio)
├── screens/             # search, library, playlist, player, settings
├── widgets/             # TrackTile, DownloadButton, MiniPlayer, CoverPlaceholder
└── utils/playlist_io.dart # импорт/экспорт XML
```

## Использованные технологии

| Пакет | Назначение |
|---|---|
| `youtube_explode_dart` | Поиск и скачивание с YouTube |
| `just_audio` + `just_audio_background` | Воспроизведение, очередь, уведомление |
| `sqflite` | Локальная база данных |
| `provider` | Управление состоянием |
| `xml` | Импорт/экспорт плейлистов |
| `path_provider` | Папки приложения |
| `url_launcher` | Ссылка на GitHub Releases |

## Известные ограничения

- `youtube_explode_dart` зависит от доступности YouTube API-эндпоинтов; если источник недоступен, приложение покажет соответствующее сообщение и предложит проверить обновления в Releases.
- Для desktop-сборки дополнительно требуется `sqflite_common_ffi` (закомментирован в `pubspec.yaml`).
- Скачивание защищённых/возрастных видео может не работать.

## Лицензия

Проект распространяется под лицензией **MIT**. См. [LICENSE](LICENSE).

```
MIT License

Copyright (c) 2026 Danile Khrebkov

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

> ⚠️ Примечание: Hoginote скачивает аудио с YouTube. Убедитесь, что ваши действия соответствуют Условиям использования YouTube и законодательству вашей страны. Авторы приложения не несут ответственности за использование.
