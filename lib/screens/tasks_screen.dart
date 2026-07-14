import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import '../services/app_store.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  static const statuses = <(String, String)>[
    ('next', 'Далее'),
    ('doing', 'В работе'),
    ('blocked', 'Ожидает'),
    ('done', 'Готово'),
  ];

  late final TabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: statuses.length, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Задачи'),
        bottom: TabBar(
          controller: tabs,
          isScrollable: true,
          tabs: statuses.map((status) => Tab(text: status.$2)).toList(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Задача'),
      ),
      body: TabBarView(
        controller: tabs,
        children:
            statuses.map((status) {
              final items =
                  widget.store.data.tasks
                      .where((task) => task.status == status.$1)
                      .toList();
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final task = items[index];
                  final project = widget.store.data.projects.firstWhere(
                    (project) => project.id == task.projectId,
                  );
                  return Card(
                    child: ListTile(
                      leading: Checkbox(
                        value: task.status == 'done',
                        onChanged: (checked) {
                          widget.store.updateTaskStatus(
                            task,
                            checked == true ? 'done' : 'next',
                          );
                          setState(() {});
                        },
                      ),
                      title: Text(task.title),
                      subtitle: Text(
                        '${project.emoji} ${project.title} · '
                        '${task.estimateMinutes} мин',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          widget.store.updateTaskStatus(task, value);
                          setState(() {});
                        },
                        itemBuilder:
                            (_) =>
                                statuses
                                    .map(
                                      (item) => PopupMenuItem<String>(
                                        value: item.$1,
                                        child: Text(item.$2),
                                      ),
                                    )
                                    .toList(),
                      ),
                    ),
                  );
                },
              );
            }).toList(),
      ),
    );
  }

  Future<void> _add() async {
    final controller = TextEditingController();
    var projectId = widget.store.data.projects.first.id;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Новая задача',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Название'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: projectId,
                items:
                    widget.store.data.projects
                        .map(
                          (project) => DropdownMenuItem<String>(
                            value: project.id,
                            child: Text('${project.emoji} ${project.title}'),
                          ),
                        )
                        .toList(),
                onChanged: (value) {
                  if (value != null) projectId = value;
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final title = controller.text.trim();
                    if (title.isEmpty) return;
                    widget.store.addTask(
                      WorkTask(
                        id: const Uuid().v4(),
                        title: title,
                        projectId: projectId,
                      ),
                    );
                    Navigator.pop(sheetContext);
                    setState(() {});
                  },
                  child: const Text('Создать'),
                ),
              ),
            ],
          ),
        );
      },
    );

    controller.dispose();
  }
}
