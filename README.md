```markdown
# Hoginote — Техническое задание для генерации кода

## 0. Общая информация

**Название проекта:** Hoginote
**Тип:** Кроссплатформенное приложение для прослушивания музыки (офлайн)
**Платформы:** Android, iOS, Desktop (Windows/macOS/Linux) — единая кодовая база Flutter
**Язык интерфейса:** Русский
**Тема:** Только тёмная, около-бежевые тона

**Ключевые ограничения:**
- Нет регистрации, нет сбора данных, нет серверной части
- Вся логика и данные — на устройстве пользователя
- Источник музыки: YouTube (через `youtube_explode_dart`)
- Скачанные треки хранятся в приватной папке приложения (офлайн-воспроизведение)
- Фоновое воспроизведение с уведомлением (Android foreground service)

**Название и иконка:**
- Название: `Hoginote` (от ника разработчика)
- Иконка: сгенерировать простую иконку — стилизованный свиной пятачок (минимум деталей) на бежевом/тёмном фоне. Формат: SVG или PNG 1024x1024, разместить в `assets/icon/`.

---

## 1. Стек и зависимости

```yaml
# pubspec.yaml (dependencies)
flutter:
  sdk: flutter

youtube_explode_dart: ^2.3.4
just_audio: ^0.9.40
just_audio_background: ^0.0.1-beta.11
sqflite: ^2.3.0
path: ^1.9.0
path_provider: ^2.1.0
provider: ^6.1.0
xml: ^6.5.0
```

`just_audio_background` требует `audio_service` (устанавливается транзитивно). Настройка AndroidManifest — см. Модуль 1.

---

## 2. Архитектура проекта (структура папок)

```
lib/
├── main.dart
├── app.dart
├── theme/
│   └── app_theme.dart
├── models/
│   ├── track.dart
│   └── playlist.dart
├── data/
│   ├── database_helper.dart
│   └── youtube_service.dart
├── audio/
│   └── audio_handler.dart
├── screens/
│   ├── search_screen.dart
│   ├── player_screen.dart
│   ├── library_screen.dart
│   ├── playlist_screen.dart
│   └── settings_screen.dart
├── widgets/
│   ├── track_tile.dart
│   ├── download_button.dart
│   └── mini_player.dart
└── utils/
    └── playlist_io.dart
```

---

## 3. Модуль 1: Каркас проекта и настройка платформ

### 3.1. `main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.hoginote.audio',
    androidNotificationChannelName: 'Hoginote',
    androidNotificationOngoing: true,
  );

  runApp(const HoginoteApp());
}
```

### 3.2. Android: `android/app/src/main/AndroidManifest.xml`

Добавить внутри `<manifest>` (до `<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>
```

Внутри `<application>` заменить `MainActivity` на `AudioServiceActivity` и добавить службу + receiver:

```xml
<activity
    android:name="com.ryanheise.audioservice.AudioServiceActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme"
    android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
    android:hardwareAccelerated="true"
    android:windowSoftInputMode="adjustResize">
    <meta-data
        android:name="io.flutter.embedding.android.NormalTheme"
        android:resource="@style/NormalTheme" />
    <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
    </intent-filter>
</activity>

<service
    android:name="com.ryanheise.audioservice.AudioService"
    android:foregroundServiceType="mediaPlayback"
    android:exported="true">
    <intent-filter>
        <action android:name="android.media.browse.MediaBrowserService"/>
    </intent-filter>
</service>

<receiver
    android:name="com.ryanheise.audioservice.MediaButtonReceiver"
    android:exported="true">
    <intent-filter>
        <action android:name="android.intent.action.MEDIA_BUTTON"/>
    </intent-filter>
</receiver>
```

В `android/app/build.gradle` установить `minSdkVersion 21`.

### 3.3. iOS: `ios/Runner/Info.plist`

Добавить:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### 3.4. Desktop

Для Windows/macOS/Linux дополнительных разрешений не требуется. Убедиться, что `just_audio_background` поддерживает desktop.

---

## 4. Модуль 2: SQLite схема и DatabaseHelper

### 4.1. Таблицы

```sql
CREATE TABLE tracks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    youtube_id TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    author TEXT NOT NULL,
    duration_ms INTEGER NOT NULL,
    file_path TEXT NOT NULL,
    downloaded_at INTEGER NOT NULL
);

CREATE TABLE playlists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    created_at INTEGER NOT NULL
);

CREATE TABLE playlist_tracks (
    playlist_id INTEGER NOT NULL,
    track_id INTEGER NOT NULL,
    position INTEGER NOT NULL,
    PRIMARY KEY (playlist_id, track_id),
    FOREIGN KEY (playlist_id) REFERENCES playlists(id) ON DELETE CASCADE,
    FOREIGN KEY (track_id) REFERENCES tracks(id) ON DELETE CASCADE
);
```

Индексы:

```sql
CREATE INDEX idx_tracks_title ON tracks(title);
CREATE INDEX idx_tracks_author ON tracks(author);
```

### 4.2. `data/database_helper.dart`

Класс-синглтон `DatabaseHelper` с методами:

| Метод | Описание |
|-------|----------|
| `Future<Database> get database` | ленивая инициализация, путь через `getApplicationDocumentsDirectory()` |
| `Future<int> insertTrack(Track track)` | вставка, `ConflictAlgorithm.ignore` по `youtube_id` |
| `Future<List<Track>> getAllTracks()` | все треки, сортировка по `downloaded_at DESC` |
| `Future<Track?> getTrackByYoutubeId(String id)` | для проверки дубликатов |
| `Future<void> deleteTrack(int id)` | удалить трек (и файл с диска) |
| `Future<int> createPlaylist(String name)` | создать плейлист |
| `Future<List<Playlist>> getAllPlaylists()` | все плейлисты |
| `Future<List<Track>> getTracksForPlaylist(int playlistId)` | треки плейлиста по `position` |
| `Future<void> addTrackToPlaylist(int playlistId, int trackId)` | добавить, `position = max + 1` |
| `Future<void> removeTrackFromPlaylist(int playlistId, int trackId)` | удалить |
| `Future<void> clearAll()` | удалить все записи из всех таблиц |

При `deleteTrack` и `clearAll` удалять соответствующие файлы с диска (`File(filePath).delete()`).

---

## 5. Модуль 3: YouTube-сервис

### 5.1. `data/youtube_service.dart`

```dart
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YoutubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<SearchResultItem>> search(String query) async {
    final videoId = VideoId.parseVideoId(query);
    if (videoId != null) {
      final video = await _yt.videos.get(videoId);
      return [SearchResultItem.fromVideo(video)];
    }

    final results = await _yt.search.search(query);
    return results.map((v) => SearchResultItem.fromVideo(v)).toList();
  }

  Future<String> downloadAudio(
    String videoId,
    String saveDir, {
    void Function(double progress)? onProgress,
  }) async {
    final manifest = await _yt.videos.streams.getManifest(videoId);
    final audioStreamInfo = manifest.audioOnly.withHighestBitrate();
    final stream = _yt.videos.streams.get(audioStreamInfo);

    final filePath = '$saveDir/$videoId.m4a';
    final file = File(filePath);
    final fileStream = file.openWrite();

    final totalBytes = audioStreamInfo.size.totalBytes;
    var downloadedBytes = 0;

    await for (final chunk in stream) {
      downloadedBytes += chunk.length;
      fileStream.add(chunk);
      onProgress?.call(downloadedBytes / totalBytes);
    }

    await fileStream.flush();
    await fileStream.close();
    return filePath;
  }

  void dispose() => _yt.close();
}
```

Модель `SearchResultItem` (в `models/track.dart` или отдельно):
- `videoId`, `title`, `author`, `duration` (Duration)

### 5.2. Обработка ошибок

Все вызовы YouTube оборачивать в `try/catch`. При исключении:
- Показать пользователю: `"Источник недоступен. Проверьте наличие новой версии на github.com/<ваш_ник>/Hoginote/releases"`
- Логировать только в debug-режиме (не отправлять никуда).

---

## 6. Модуль 4: Аудио-движок

### 6.1. `audio/audio_handler.dart`

Использовать `just_audio_background`. Пример структуры:

```dart
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class AudioHandler {
  final AudioPlayer _player = AudioPlayer();
  List<Track> _queue = [];
  int _currentIndex = 0;

  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue = tracks;
    _currentIndex = startIndex;
    await _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final track = _queue[_currentIndex];
    await _player.setAudioSource(
      AudioSource.file(
        track.filePath,
        tag: MediaItem(
          id: track.id.toString(),
          title: track.title,
          artist: track.author,
        ),
      ),
    );
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> next() async { }
  Future<void> previous() async { }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<bool> get playingStream => _player.playingStream;
}
```

`tag: MediaItem(...)` обязателен для отображения метаданных в уведомлении.

### 6.2. Очередь

Очередь = либо «Все треки» (из библиотеки), либо треки конкретного плейлиста. При запуске трека из списка — установить очередь на весь список, начиная с выбранного индекса.

---

## 7. Модуль 5: UI-экраны

### 7.1. Тема (`theme/app_theme.dart`)

```dart
const Color bgDark = Color(0xFF1A1815);
const Color bgCard = Color(0xFF24211D);
const Color accentBeige = Color(0xFFD4C4A8);
const Color textPrimary = Color(0xFFEDE8E0);
const Color textSecondary = Color(0xFFA89F94);
```

`ThemeData`:
- `brightness: Brightness.dark`
- `scaffoldBackgroundColor: bgDark`
- `colorScheme.primary: accentBeige`
- Шрифт по умолчанию (Roboto/system)
- Скругления: `BorderRadius.circular(12)`

### 7.2. Навигация

Мобильные (Android/iOS): `BottomNavigationBar` с 3 вкладками:
1. Поиск (иконка поиска)
2. Библиотека (иконка библиотеки/папки)
3. Настройки (иконка шестерёнки)

Desktop: `NavigationRail` слева (постоянно видимый или раскрывающийся) с теми же 3 пунктами. Реализовать через проверку `Platform.isAndroid || Platform.isIOS` → bottom bar, иначе → rail.

### 7.3. Экран «Поиск» (`search_screen.dart`)

Виджеты:
- `TextField` вверху: подсказка `"Название, автор или ссылка YouTube"`, иконка поиска, кнопка очистки.
- `ListView` результатов: каждый элемент — `TrackTile` (обложка-заглушка слева, название, автор, длительность, кнопка скачивания справа).
- `TrackTile`: кнопка скачивания — `DownloadButton`.

Состояния:
- Пустой ввод → показать текст `"Введите название, автора или ссылку"`
- Идёт поиск → `CircularProgressIndicator` по центру
- Ничего не найдено → текст `"Ничего не найдено"` + иконка
- Ошибка (YouTube недоступен) → текст ошибки + кнопка `"Проверить обновления"` (открывает URL GitHub Releases через `url_launcher`)

Скачивание:
- При нажатии на кнопку скачивания: если трек уже есть в БД (по `youtube_id`) → показать `"Уже скачано"` (SnackBar) и не качать повторно.
- Иначе: кнопка превращается в `CircularProgressIndicator` с прогрессом (0..1). По завершении — SnackBar `"Скачано: <название>"`, кнопка становится галочкой.

Поиск по ссылке: если ввод содержит `youtube.com/watch` или `youtu.be/` — извлечь `videoId`, получить метаданные через `YoutubeService`, показать один результат.

### 7.4. Экран «Плеер» (`player_screen.dart`)

Стиль: похож на Spotify, но в тёмно-бежевых тонах.

Элементы (сверху вниз):
- Кнопка «вниз» (свернуть) слева вверху
- Большая квадратная обложка (заглушка: иконка ноты на фоне `bgCard`, скругления)
- Название трека (крупно, `textPrimary`, `maxLines: 1`, `overflow: ellipsis`)
- Автор (средне, `textSecondary`)
- `Slider` прогресса (активный цвет — `accentBeige`, неактивный — `textSecondary.withOpacity(0.3)`)
- Тайминги: слева текущее время, справа общая длительность (формат `mm:ss`)
- Ряд кнопок: `shuffle` (опционально, можно скрыть в MVP), `previous`, `play/pause` (крупная, в круге `accentBeige`), `next`, `repeat` (опционально)

Фон: `bgDark`. Опционально: лёгкое размытие (blur) от обложки — но можно пропустить в MVP.

### 7.5. Экран «Библиотека» (`library_screen.dart`)

Две вкладки внутри экрана (TabBar):

Вкладка 1: «Все треки»
- `ListView` всех скачанных треков (сортировка: новые сверху)
- Каждый элемент: `TrackTile` с кнопкой «играть» (тап по всему элементу → запуск плеера с очередью = все треки)
- Долгое нажатие → контекстное меню: «Добавить в плейлист», «Удалить» (удаляет из БД и с диска)
- Пустое состояние: иконка + текст `"Скачайте первый трек во вкладке Поиск"`

Вкладка 2: «Плейлисты»
- `ListView` плейлистов: название, количество треков, дата создания
- Кнопка «+» в AppBar: создать плейлист (диалог с `TextField` для имени)
- Кнопка «Вставить плейлист» (иконка буфера обмена) в AppBar или FloatingActionButton: открывает диалог для вставки XML (см. Модуль 6)
- Тап по плейлисту → `PlaylistScreen`
- Пустое состояние: текст `"Нет плейлистов. Создайте или вставьте из XML"`

### 7.6. Экран «Плейлист» (`playlist_screen.dart`)

- AppBar: название плейлиста, кнопка «играть всё» (запуск очереди = треки плейлиста), кнопка меню (переименовать/удалить).
- `ListView` треков плейлиста (с `position`)
- Кнопка «Добавить треки»: открывает экран/диалог со списком всех скачанных треков с чекбоксами → добавить выбранные.
- Свайп влево по треку → удалить из плейлиста (но не с диска).

### 7.7. Экран «Настройки» (`settings_screen.dart`)

- Секция «О приложении»:
  - Название `Hoginote`
  - Версия (`1.0.0` — захардкодить или из `pubspec.yaml` через `package_info_plus`, но можно захардкодить в MVP)
  - Краткое описание: `"Офлайн-плеер для музыки из YouTube. Без регистрации. Без сбора данных."`
- Кнопка `"Проверить обновления"`: открывает `https://github.com/<ваш_ник>/Hoginote/releases` в браузере.
- Секция «Данные»:
  - Кнопка `"Очистить всё скачанное"` (красный текст, использовать `Colors.redAccent`).
  - При нажатии: диалог подтверждения `"Удалить все треки, плейлисты и файлы? Это действие нельзя отменить."` → при подтверждении: `DatabaseHelper.clearAll()` + удаление всех файлов из папки загрузок + SnackBar `"Всё удалено"`.

### 7.8. Mini-player

Внизу экрана (над BottomNavigationBar) — тонкая полоса с текущим треком (название, автор, play/pause). Тап → открыть полный плеер. Показывать только если есть активный трек.

---

## 8. Модуль 6: Импорт/экспорт плейлистов (XML)

### 8.1. Формат XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<hoginote-playlist name="Мой плейлист">
    <track youtube_id="dQw4w9WgXcQ" title="Never Gonna Give You Up" author="Rick Astley"/>
    <track youtube_id="..." title="..." author="..."/>
</hoginote-playlist>
```

### 8.2. Импорт («Вставить плейлист»)

1. Пользователь нажимает кнопку → открывается диалог с многострочным `TextField` (или используется `Clipboard.getData`).
2. Пользователь вставляет XML → нажимает «Импортировать».
3. Парсинг через пакет `xml`:
   - Извлечь `name` (если нет — `"Импортированный плейлист"`).
   - Создать плейлист в БД.
   - Для каждого `<track>`:
     - Проверить, есть ли трек в БД по `youtube_id`.
     - Если нет — добавить в очередь скачивания (см. ниже).
     - Если есть — добавить в плейлист.
4. Показать прогресс: `"Импорт: 3/10 треков"`.
5. Для отсутствующих треков: последовательно скачать через `YoutubeService.downloadAudio`, после каждого — добавить в БД и в плейлист.
6. При ошибке скачивания одного трека — пропустить, продолжить, в конце показать `"Импортировано X из Y. Z треков не удалось скачать."`

Не блокировать UI. Использовать `Future` и обновлять прогресс через `setState`/провайдер.

### 8.3. Экспорт

Кнопка в экране плейлиста: «Экспортировать в XML». Сгенерировать XML по формату выше, скопировать в буфер обмена (`Clipboard.setData`), показать SnackBar `"XML скопирован в буфер обмена"`.

---

## 9. Модуль 7: Обработка ошибок и пустые состояния

| Ситуация | Действие |
|----------|----------|
| YouTube недоступен (поиск/скачивание) | SnackBar/Dialog: `"Источник недоступен. Проверьте наличие новой версии на github.com/<ник>/Hoginote/releases"` |
| Нет интернета при поиске | То же сообщение (не показывать технические детали) |
| Скачивание прервано | SnackBar `"Ошибка скачивания. Попробуйте позже."` |
| Поиск пуст | Текст `"Ничего не найдено"` |
| Библиотека пуста | Текст `"Скачайте первый трек"` + иконка |
| Плейлистов нет | Текст `"Создайте плейлист или вставьте XML"` |
| Ошибка парсинга XML | SnackBar `"Неверный формат XML"` |

Никогда не показывать пользователю stack trace или технические сообщения об ошибках YouTube.

---

## 10. Модуль 8: README + инструкция по сборке

Сгенерировать `README.md` в корне проекта:

```markdown
# Hoginote

Офлайн-плеер для музыки из YouTube. Без регистрации. Без сбора данных.

## Возможности
- Поиск треков на YouTube (название, автор, ссылка)
- Скачивание аудио для офлайн-прослушивания
- Фоновое воспроизведение с управлением из уведомления
- Локальные плейлисты
- Импорт/экспорт плейлистов в XML

## Сборка

### Требования
- Flutter SDK (stable, >= 3.10)
- Android SDK (для Android)
- Xcode (для iOS, только macOS)

### Шаги
```bash
git clone https://github.com/<ваш_ник>/Hoginote.git
cd Hoginote
flutter pub get
flutter build apk --release
```

APK будет в `build/app/outputs/flutter-apk/app-release.apk`.

### Подпись APK (для GitHub Releases)
Следуйте официальной инструкции Flutter: https://docs.flutter.dev/deployment/android#signing-the-app

## Лицензия
MIT (или ваша)
```

---

## 11. Критерии готовности (Definition of Done)

Приложение считается готовым, если:

1. Собирается в APK без ошибок (`flutter build apk --release`).
2. Поиск работает: ввод названия/автора/ссылки → список результатов.
3. Скачивание работает: кнопка с круговым прогрессом, файл сохраняется, трек появляется в «Все треки».
4. Воспроизведение работает: тап по треку → играет, плеер отображает метаданные.
5. Фоновое воспроизведение: свёрнутое приложение → музыка играет, уведомление с управлением.
6. Библиотека: все скачанные треки отображаются, удаление работает.
7. Плейлисты: создание, добавление треков, удаление из плейлиста.
8. XML-импорт: вставка XML → создание плейлиста → скачивание отсутствующих треков.
9. Настройки: «Очистить всё» работает (БД + файлы).
10. Тема: тёмная, бежевые акценты.
11. README с инструкцией по сборке.

---

## 12. Примечания для генерации кода

- Генерировать код по модулям, начиная с Модуля 1 (каркас), затем 2 (БД), 3 (YouTube), 4 (аудио), 5 (UI), 6 (XML), 7 (ошибки), 8 (README).
- Для каждого файла указывать полный путь (например, `lib/data/database_helper.dart`).
- Использовать `provider` для передачи `AudioHandler` и `DatabaseHelper` в виджеты.
- Не использовать `setState` для глобального состояния — только для локального (прогресс скачивания в конкретном виджете).
- Все строки интерфейса — на русском.
- Не добавлять никакой аналитики, трекинга, логирования на сервер.
- Если какая-то библиотека несовместима с desktop (например, `sqflite` требует `sqflite_common_ffi` для desktop) — добавить соответствующую зависимость и инициализацию. Для MVP можно ограничиться Android, но структура должна позволять добавить desktop позже.

---

**Конец ТЗ.**
```