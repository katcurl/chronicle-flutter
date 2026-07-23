import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/app_store.dart';
import 'devices_screen.dart';
import '../widgets/common.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final total = store.data.entries.fold<int>(
      0,
      (sum, entry) => sum + entry.durationSeconds,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
        actions: [
          IconButton(
            tooltip: 'Связанные устройства',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DevicesScreen(store: store),
                ),
              );
            },
            icon: const Icon(Icons.devices_other_rounded),
          ),
          IconButton(
            tooltip: 'Резервная копия',
            onPressed: () => _openBackupSheet(context),
            icon: const Icon(Icons.backup_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          MetricCard(
            icon: Icons.timer_outlined,
            label: 'Всего учтено',
            value: formatDuration(total),
          ),
          const SizedBox(height: 10),
          MetricCard(
            icon: Icons.auto_stories_outlined,
            label: 'Заметок',
            value: '${store.data.notes.length}',
          ),
          const SizedBox(height: 10),
          MetricCard(
            icon: Icons.done_all_rounded,
            label: 'Завершено задач',
            value:
                '${store.data.tasks.where((task) => task.status == 'done').length}',
          ),
          const SizedBox(height: 22),
          const SectionTitle('По проектам'),
          ...store.activeProjects.map((project) {
            final seconds = store.data.entries
                .where((entry) => entry.projectId == project.id)
                .fold<int>(0, (sum, entry) => sum + entry.durationSeconds);
            final ratio = total == 0 ? 0.0 : seconds / total;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(project.emoji),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              project.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(formatDuration(seconds)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: ratio,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openBackupSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Резервная копия',
                    style: Theme.of(sheetContext).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Экспорт включает проекты, задачи, заметки и учтённое время.',
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.copy_all_outlined),
                    title: const Text('Скопировать JSON-копию'),
                    subtitle: const Text('Можно сохранить текст в любом файле'),
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final json = await store.exportBackupJson();
                      await Clipboard.setData(ClipboardData(text: json));
                      if (!sheetContext.mounted) return;
                      Navigator.pop(sheetContext);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Резервная копия скопирована'),
                        ),
                      );
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.settings_backup_restore_rounded),
                    title: const Text('Восстановить из JSON'),
                    subtitle: const Text('Текущие данные будут заменены'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showImportDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _showImportDialog(BuildContext context) async {
    final controller = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Восстановить данные'),
            content: SizedBox(
              width: 560,
              child: TextField(
                controller: controller,
                autofocus: true,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(
                  hintText: 'Вставь JSON резервной копии',
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () async {
                  try {
                    await store.importBackupJson(controller.text.trim());
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Данные восстановлены')),
                    );
                  } on Object catch (error) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Не удалось импортировать: $error'),
                      ),
                    );
                  }
                },
                child: const Text('Восстановить'),
              ),
            ],
          ),
    );

    controller.dispose();
  }
}
