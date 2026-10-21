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
git clone https://github.com/DanileKhrebkov/HogiNote.git
cd HogiNote
flutter pub get
flutter build apk --release
```

APK будет в `build/app/outputs/flutter-apk/app-release.apk`.

### Подпись APK (для GitHub Releases)
Следуйте официальной инструкции Flutter: https://docs.flutter.dev/deployment/android#signing-the-app

## Лицензия
MIT
