import 'package:flutter/material.dart';

import '../features/appearance/app_appearance.dart';
import '../features/projects/project_appearance_store.dart';
import '../features/projects/project_appearance_widgets.dart';
import '../features/projects/project_detail_screen.dart';
import '../features/projects/project_editor_sheet.dart';
import '../features/tasks/task_metadata.dart';
import '../models/app_models.dart';
import '../services/app_store.dart';
import '../widgets/common.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({
    super.key,
    required this.store,
    required this.appearanceController,
    required this.globalAppearance,
  });

  final AppStore store;
  final ProjectAppearanceController appearanceController;
  final AppAppearancePreferences globalAppearance;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool showArchived = false;

  @override
  Widget build(BuildContext context) {
    final projects =
        showArchived
            ? widget.store.archivedProjects
            : widget.store.activeProjects;

    return Scaffold(
      appBar: AppBar(
        title: Text(showArchived ? 'Архив проектов' : 'Проекты'),
        actions: [
          IconButton(
            tooltip: showArchived ? 'Активные проекты' : 'Архив',
            onPressed: () => setState(() => showArchived = !showArchived),
            icon: Icon(
              showArchived
                  ? Icons.folder_open_rounded
                  : Icons.inventory_2_outlined,
            ),
          ),
        ],
      ),
      floatingActionButton:
          showArchived
              ? null
              : FloatingActionButton.extended(
                onPressed: _add,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Проект'),
              ),
      body:
          projects.isEmpty
              ? _EmptyProjects(archived: showArchived)
              : LayoutBuilder(
                builder: (context, constraints) {
                  final columns =
                      constraints.maxWidth >= 1100
                          ? 3
                          : constraints.maxWidth >= 680
                          ? 2
                          : 1;
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: 220,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: projects.length,
                    itemBuilder:
                        (_, index) => _ProjectCard(
                          project: projects[index],
                          store: widget.store,
                          appearanceController: widget.appearanceController,
                          globalAppearance: widget.globalAppearance,
                          onOpen: () => _open(projects[index]),
                          onEdit: () => _edit(projects[index]),
                          onArchive: () async {
                            await widget.store.setProjectArchived(
                              projects[index],
                              !projects[index].archived,
                            );
                            if (mounted) {
                              setState(() {});
                            }
                          },
                        ),
                  );
                },
              ),
    );
  }

  Future<void> _add() async {
    final result = await ProjectEditorSheet.show(
      context,
      appearanceController: widget.appearanceController,
      globalAppearance: widget.globalAppearance,
    );
    if (result == null) return;
    await widget.store.addProject(result.project);
    await _saveAppearance(result);
    if (mounted) setState(() {});
  }

  Future<void> _edit(Project project) async {
    final result = await ProjectEditorSheet.show(
      context,
      project: project,
      appearanceController: widget.appearanceController,
      globalAppearance: widget.globalAppearance,
    );
    if (result == null) return;
    await widget.store.updateProject(result.project);
    await _saveAppearance(result);
    if (mounted) setState(() {});
  }

  Future<void> _saveAppearance(ProjectEditorResult result) async {
    try {
      await widget.appearanceController.saveProjectAppearance(
        result.project.id,
        result.appearance,
        icon: result.icon,
        removeIcon: result.removeIcon,
        background: result.background,
        removeBackground: result.removeBackground,
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить оформление: $error')),
      );
    }
  }

  Future<void> _open(Project project) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder:
            (_) => ProjectDetailScreen(
              store: widget.store,
              projectId: project.id,
              appearanceController: widget.appearanceController,
              globalAppearance: widget.globalAppearance,
            ),
      ),
    );
    if (mounted) setState(() {});
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard({
    required this.project,
    required this.store,
    required this.appearanceController,
    required this.globalAppearance,
    required this.onOpen,
    required this.onEdit,
    required this.onArchive,
  });

  final Project project;
  final AppStore store;
  final ProjectAppearanceController appearanceController;
  final AppAppearancePreferences globalAppearance;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final tasks =
        store.data.tasks.where((task) => task.projectId == project.id).toList();
    final done = tasks.where((task) => task.status == 'done').length;
    final seconds = store.data.entries
        .where((entry) => entry.projectId == project.id)
        .fold<int>(0, (sum, entry) => sum + entry.durationSeconds);
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    final color = Color(project.colorValue);

    return ProjectAppearanceScope(
      projectId: project.id,
      controller: appearanceController,
      globalAppearance: globalAppearance,
      child: Builder(
        builder:
            (projectContext) => ProjectSurface(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onOpen,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ProjectAvatar(
                              project: project,
                              controller: appearanceController,
                              size: 48,
                              borderRadius: 15,
                              backgroundColor: color.withValues(alpha: 0.22),
                              emojiFontSize: 26,
                            ),
                            const Spacer(),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') onEdit();
                                if (value == 'archive') onArchive();
                              },
                              itemBuilder:
                                  (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Редактировать'),
                                    ),
                                    PopupMenuItem(
                                      value: 'archive',
                                      child: Text(
                                        project.archived
                                            ? 'Вернуть из архива'
                                            : 'Архивировать',
                                      ),
                                    ),
                                  ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(projectContext).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (project.researchGoal.isNotEmpty ||
                            project.description.isNotEmpty)
                          Text(
                            project.researchGoal.isNotEmpty
                                ? project.researchGoal
                                : project.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(projectContext).textTheme.bodySmall,
                          ),
                        const Spacer(),
                        LinearProgressIndicator(
                          value: progress,
                          borderRadius: BorderRadius.circular(99),
                          color: color,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('$done / ${tasks.length} задач'),
                            const Spacer(),
                            Text(formatDuration(seconds)),
                          ],
                        ),
                        if (project.dueAt != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.event_rounded,
                                size: 17,
                                color:
                                    isOverdue(project.dueAt)
                                        ? Theme.of(
                                          projectContext,
                                        ).colorScheme.error
                                        : null,
                              ),
                              const SizedBox(width: 6),
                              Text('До ${shortDate(project.dueAt)}'),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

class _EmptyProjects extends StatelessWidget {
  const _EmptyProjects({required this.archived});

  final bool archived;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            archived ? Icons.inventory_2_outlined : Icons.folder_rounded,
            size: 62,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            archived ? 'Архив пуст' : 'Создай первый проект',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}
