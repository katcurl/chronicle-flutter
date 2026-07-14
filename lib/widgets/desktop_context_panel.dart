import 'package:flutter/material.dart';

import '../navigation/app_section.dart';
import '../services/app_store.dart';
import 'common.dart';

class DesktopContextPanel extends StatelessWidget {
  const DesktopContextPanel({
    super.key,
    required this.store,
    required this.section,
    required this.onStartTimer,
  });

  final AppStore store;
  final AppSection section;
  final VoidCallback onStartTimer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeTasks =
        store.data.tasks.where((task) => task.status != 'done').length;
    final recentEntries = store.data.entries.take(3).toList();

    return ColoredBox(
      color: colors.surfaceContainerLowest,
      child: SafeArea(
        left: false,
        child: SizedBox(
          width: 320,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Контекст',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Текущий раздел',
                    child: Icon(section.selectedIcon, color: colors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                section.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              _TimerCard(store: store, onStartTimer: onStartTimer),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _CompactMetric(
                      label: 'Сегодня',
                      value: formatDuration(store.todaySeconds),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _CompactMetric(
                      label: 'Задачи',
                      value: '$activeTasks',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Последние сессии',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              if (recentEntries.isEmpty)
                Text(
                  'Завершённые сессии появятся здесь.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                )
              else
                ...recentEntries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 20,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                entry.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatDuration(entry.durationSeconds),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              Divider(color: colors.outlineVariant),
              const SizedBox(height: 14),
              Text(
                'Быстрые клавиши',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              const _ShortcutRow(
                keys: 'Ctrl  1–5',
                action: 'Переключить раздел',
              ),
              const SizedBox(height: 8),
              const _ShortcutRow(keys: 'Ctrl  T', action: 'Запустить таймер'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Local-first · данные хранятся на устройстве',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerCard extends StatelessWidget {
  const _TimerCard({required this.store, required this.onStartTimer});

  final AppStore store;
  final VoidCallback onStartTimer;

  @override
  Widget build(BuildContext context) {
    final running = store.activeStartedAt != null;
    final colors = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              running ? store.activeDescription : 'Текущая сессия',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              formatDuration(store.activeSeconds),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: running ? store.stopTimer : onStartTimer,
                icon: Icon(
                  running ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(running ? 'Остановить' : 'Начать работу'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.keys, required this.action});

  final String keys;
  final String action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Text(
              keys,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(action, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}
