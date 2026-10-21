import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/database_helper.dart';
import '../theme/app_theme.dart';
import '../utils/errors.dart';

/// Экран «Настройки»: о приложении, обновления, очистка данных.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const appVersion = '1.0.0';

  Future<void> _openReleases() async {
    final uri = Uri.parse(releasesUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть браузер')),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить всё скачанное?'),
        content: const Text(
          'Удалить все треки, плейлисты и файлы? '
          'Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить всё',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await DatabaseHelper.instance.clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Всё удалено')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'О ПРИЛОЖЕНИИ',
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.pets_rounded, color: accentBeige),
            title: const Text(
              'Hoginote',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Версия $appVersion',
              style: const TextStyle(color: textSecondary),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded, color: textSecondary),
            title: Text(
              'Офлайн-плеер для музыки из YouTube. '
              'Без регистрации. Без сбора данных.',
              style: TextStyle(color: textSecondary),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.system_update_alt_rounded,
                color: accentBeige),
            title: const Text('Проверить обновления'),
            onTap: _openReleases,
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'ДАННЫЕ',
              style: TextStyle(
                color: textSecondary,
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded,
                color: Colors.redAccent),
            title: const Text(
              'Очистить всё скачанное',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: _clearAll,
          ),
        ],
      ),
    );
  }
}
