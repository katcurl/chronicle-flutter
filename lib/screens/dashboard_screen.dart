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
    final activeIds = store.activeProjects.map((item) => item.id).toSet();
    final activeTasks =
        store.data.tasks
            .where(
              (task) =>
                  task.status != 'done' && activeIds.contains(task.projectId),
            )
            .toList()
          ..sort((a, b) {
            final priority = b.priority.compareTo(a.priority);
            if (priority != 0) return priority;
            if (a.dueAt != null && b.dueAt != null) {
              return a.dueAt!.compareTo(b.dueAt!);
            }
            return b.updatedAt.compareTo(a.updatedAt);
          });

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
                      value: '${activeTasks.length}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const SectionTitle('Следующие задачи'),
              if (activeTasks.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Активных задач пока нет'),
                  ),
                )
              else
                ...activeTasks.take(5).map((task) {
                  final project = store.projectById(task.projectId);
                  return Card(
                    child: ListTile(
                      onTap: () => onOpenTask(task.id),
                      leading: CircleAvatar(
                        child: Text(project?.emoji ?? '📁'),
                      ),
                      title: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${project?.title ?? 'Без проекта'} · '
                        '${task.estimateMinutes} мин',
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
                  itemCount: store.activeProjects.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, index) {
                    final project = store.activeProjects[index];
                    final seconds = store.data.entries
                        .where((entry) => entry.projectId == project.id)
                        .fold<int>(
                          0,
                          (sum, entry) => sum + entry.durationSeconds,
                        );
                    return SizedBox(
                      width: 210,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                project.emoji,
                                style: const TextStyle(fontSize: 26),
                              ),
                              const Spacer(),
                              Text(
                                project.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                formatDuration(seconds),
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
