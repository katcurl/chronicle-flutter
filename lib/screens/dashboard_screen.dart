import 'package:flutter/material.dart';
import '../services/app_store.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.onOpenTask,
    required this.onStart,
  });
  final AppStore store;
  final void Function(String) onOpenTask;
  final VoidCallback onStart;
  @override
  Widget build(BuildContext context) {
    final active = store.data.tasks.where((e) => e.status != 'done').toList();
    return CustomScrollView(
      slivers: [
        SliverAppBar.large(
          title: const Text('Сегодня'),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.search_rounded),
            ),
            const SizedBox(width: 6),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
          sliver: SliverList.list(
            children: [
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.activeStartedAt == null
                            ? 'Готова начать?'
                            : store.activeDescription,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              formatDuration(store.activeSeconds),
                              style: Theme.of(
                                context,
                              ).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed:
                                store.activeStartedAt == null
                                    ? onStart
                                    : store.stopTimer,
                            icon: Icon(
                              store.activeStartedAt == null
                                  ? Icons.play_arrow_rounded
                                  : Icons.stop_rounded,
                            ),
                            label: Text(
                              store.activeStartedAt == null ? 'Начать' : 'Стоп',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      icon: Icons.schedule_rounded,
                      label: 'Сегодня',
                      value: formatDuration(store.todaySeconds),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MetricCard(
                      icon: Icons.task_alt_rounded,
                      label: 'Активных',
                      value: '${active.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionTitle('Следующие задачи'),
              ...active.take(5).map((task) {
                final project = store.data.projects.firstWhere(
                  (p) => p.id == task.projectId,
                );
                return Card(
                  child: ListTile(
                    onTap: () => onOpenTask(task.id),
                    leading: CircleAvatar(child: Text(project.emoji)),
                    title: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${project.title} · ${task.estimateMinutes} мин',
                    ),
                    trailing: Icon(
                      task.status == 'doing'
                          ? Icons.timelapse_rounded
                          : Icons.chevron_right_rounded,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 18),
              const SectionTitle('Проекты'),
              SizedBox(
                height: 126,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: store.data.projects.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final p = store.data.projects[i];
                    final sec = store.data.entries
                        .where((e) => e.projectId == p.id)
                        .fold(0, (a, b) => a + b.durationSeconds);
                    return SizedBox(
                      width: 210,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                              const Spacer(),
                              Text(
                                p.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                formatDuration(sec),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
