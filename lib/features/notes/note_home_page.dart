import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../../services/app_store.dart';
import '../appearance/app_appearance.dart';
import '../projects/project_appearance_store.dart';
import '../projects/project_appearance_widgets.dart';
import 'note_document.dart';
import 'note_home_preferences.dart';
import 'note_templates.dart';

class NoteHomePage extends StatelessWidget {
  const NoteHomePage({
    super.key,
    required this.store,
    required this.preferences,
    required this.appearanceController,
    required this.globalAppearance,
    required this.onOpenNote,
    required this.onOpenProject,
    required this.onOpenFolder,
    required this.onCreateFromTemplate,
    required this.onOpenLibrary,
    required this.onConfigure,
  });

  final AppStore store;
  final NoteHomePreferences preferences;
  final ProjectAppearanceController appearanceController;
  final AppAppearancePreferences globalAppearance;
  final ValueChanged<Note> onOpenNote;
  final ValueChanged<String> onOpenProject;
  final ValueChanged<String> onOpenFolder;
  final ValueChanged<NoteTemplate> onCreateFromTemplate;
  final VoidCallback onOpenLibrary;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final notes = List<Note>.from(store.data.notes)
      ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
    final visibleSections = preferences.orderedSections
        .where(preferences.isVisible)
        .where(
          (section) =>
              section != NoteHomeSection.templates ||
              store.applicableNoteTemplates.isNotEmpty,
        )
        .toList(growable: false);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _OverviewHeader(
              noteCount: notes.length,
              projectCount: store.activeProjects.length,
              pinnedCount: notes.where((note) => note.pinned).length,
              onOpenLibrary: onOpenLibrary,
              onConfigure: onConfigure,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: SliverList.builder(
            itemCount: visibleSections.length,
            itemBuilder: (_, index) {
              final section = visibleSections[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _buildSection(section, notes),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    NoteHomeSection section,
    List<Note> notes,
  ) {
    return switch (section) {
      NoteHomeSection.continueWork => _noteSection(
        section: section,
        notes: _continueNotes(notes),
        emptyText: 'Активных записей пока нет.',
      ),
      NoteHomeSection.pinned => _noteSection(
        section: section,
        notes: notes.where((note) => note.pinned).take(preferences.itemLimit),
        emptyText: 'Закрепите важную заметку, и она появится здесь.',
      ),
      NoteHomeSection.recent => _recentSection(
        notes.take(preferences.itemLimit).toList(growable: false),
      ),
      NoteHomeSection.projects => _projectSection(),
      NoteHomeSection.folders => _folderSection(notes),
      NoteHomeSection.templates => _templateSection(),
    };
  }

  List<Note> _continueNotes(List<Note> notes) {
    final result = <Note>[];
    final seen = <String>{};

    void add(Note? note) {
      if (note == null || !seen.add(note.id)) return;
      result.add(note);
    }

    add(store.activeNoteId == null ? null : store.noteById(store.activeNoteId!));

    final activeTaskNoteIds = store.data.tasks
        .where((task) => task.status != 'done' && task.noteId != null)
        .map((task) => task.noteId!)
        .toSet();
    for (final note in notes) {
      if (activeTaskNoteIds.contains(note.id)) add(note);
      if (result.length >= preferences.itemLimit) break;
    }
    for (final note in notes) {
      add(note);
      if (result.length >= preferences.itemLimit) break;
    }
    return result.take(preferences.itemLimit).toList(growable: false);
  }

  Widget _noteSection({
    required NoteHomeSection section,
    required Iterable<Note> notes,
    required String emptyText,
  }) {
    final items = notes.toList(growable: false);
    return _HomeSection(
      title: section.label,
      icon: _sectionIcon(section),
      child: items.isEmpty
          ? _EmptySection(text: emptyText)
          : SizedBox(
              height: preferences.compactCards ? 136 : 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, index) => SizedBox(
                  width: preferences.compactCards ? 230 : 276,
                  child: _HomeNoteCard(
                    store: store,
                    note: items[index],
                    appearanceController: appearanceController,
                    compact: preferences.compactCards,
                    onTap: () => onOpenNote(items[index]),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _recentSection(List<Note> notes) {
    return _HomeSection(
      title: NoteHomeSection.recent.label,
      icon: _sectionIcon(NoteHomeSection.recent),
      trailing: TextButton(
        onPressed: onOpenLibrary,
        child: const Text('Все заметки'),
      ),
      child: notes.isEmpty
          ? const _EmptySection(text: 'Недавних заметок пока нет.')
          : Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < notes.length; index++) ...[
                    _RecentNoteTile(
                      store: store,
                      note: notes[index],
                      onTap: () => onOpenNote(notes[index]),
                    ),
                    if (index != notes.length - 1)
                      const Divider(height: 1, indent: 58),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _projectSection() {
    final projects = store.activeProjects
        .take(preferences.itemLimit)
        .toList(growable: false);
    return _HomeSection(
      title: NoteHomeSection.projects.label,
      icon: _sectionIcon(NoteHomeSection.projects),
      child: projects.isEmpty
          ? const _EmptySection(text: 'Активных проектов пока нет.')
          : SizedBox(
              height: preferences.compactCards ? 122 : 148,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: projects.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final project = projects[index];
                  final projectNotes = store.data.notes
                      .where((note) => note.projectId == project.id)
                      .toList();
                  projectNotes.sort(
                    (left, right) => right.updatedAt.compareTo(left.updatedAt),
                  );
                  return SizedBox(
                    width: preferences.compactCards ? 210 : 250,
                    child: ProjectAppearanceScope(
                      projectId: project.id,
                      controller: appearanceController,
                      globalAppearance: globalAppearance,
                      child: Builder(
                        builder: (projectContext) => ProjectSurface(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                            onTap: () => onOpenProject(project.id),
                            child: Padding(
                              padding: EdgeInsets.all(
                                preferences.compactCards ? 14 : 18,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      ProjectAvatar(
                                        project: project,
                                        controller: appearanceController,
                                        size: 34,
                                        borderRadius: 10,
                                        emojiFontSize: 22,
                                      ),
                                      const Spacer(),
                                      Text('${projectNotes.length} заметок'),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    project.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(projectContext)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  if (!preferences.compactCards &&
                                      projectNotes.isNotEmpty)
                                    Text(
                                      projectNotes.first.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(
                                        projectContext,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _folderSection(List<Note> notes) {
    final counts = <String, int>{};
    for (final note in notes) {
      final folder = note.folderPath.trim();
      if (folder.isEmpty) continue;
      counts.update(folder, (value) => value + 1, ifAbsent: () => 1);
    }
    final folders = counts.entries.toList()
      ..sort((left, right) {
        final count = right.value.compareTo(left.value);
        return count != 0 ? count : left.key.compareTo(right.key);
      });
    final visible = folders.take(preferences.itemLimit).toList(growable: false);
    return _HomeSection(
      title: NoteHomeSection.folders.label,
      icon: _sectionIcon(NoteHomeSection.folders),
      child: visible.isEmpty
          ? const _EmptySection(
              text: 'Папки появятся после заполнения пути у заметки.',
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final folder in visible)
                  ActionChip(
                    avatar: const Icon(Icons.folder_outlined, size: 18),
                    label: Text('${folder.key} · ${folder.value}'),
                    onPressed: () => onOpenFolder(folder.key),
                  ),
              ],
            ),
    );
  }

  Widget _templateSection() {
    final templates = store.applicableNoteTemplates
        .take(preferences.itemLimit)
        .toList(growable: false);
    return _HomeSection(
      title: NoteHomeSection.templates.label,
      icon: _sectionIcon(NoteHomeSection.templates),
      child: templates.isEmpty
          ? const _EmptySection(text: 'Шаблоны пока недоступны.')
          : SizedBox(
              height: preferences.compactCards ? 112 : 136,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: templates.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return SizedBox(
                    width: preferences.compactCards ? 210 : 244,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onCreateFromTemplate(template),
                        child: Padding(
                          padding: EdgeInsets.all(
                            preferences.compactCards ? 14 : 18,
                          ),
                          child: Row(
                            children: [
                              Text(
                                template.icon,
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      template.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                    if (!preferences.compactCards)
                                      Text(
                                        template.isCustom
                                            ? 'Пользовательский шаблон'
                                            : 'Создать заметку',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.add_rounded),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.noteCount,
    required this.projectCount,
    required this.pinnedCount,
    required this.onOpenLibrary,
    required this.onConfigure,
  });

  final int noteCount;
  final int projectCount;
  final int pinnedCount;
  final VoidCallback onOpenLibrary;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 16,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Твоя база знаний',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$noteCount заметок · $projectCount проектов · '
                    '$pinnedCount закреплено',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: onConfigure,
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Настроить'),
                ),
                FilledButton.icon(
                  onPressed: onOpenLibrary,
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('Все заметки'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSection extends StatelessWidget {
  const _HomeSection({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _HomeNoteCard extends StatelessWidget {
  const _HomeNoteCard({
    required this.store,
    required this.note,
    required this.appearanceController,
    required this.compact,
    required this.onTap,
  });

  final AppStore store;
  final Note note;
  final ProjectAppearanceController appearanceController;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final project = store.projectById(note.projectId);
    final parsed = NoteDocument.parse(note.body);
    final snippet = _plainSnippet(parsed.content);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 14 : 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(noteTypeIcon(note.noteType)),
                  const SizedBox(width: 7),
                  if (project != null) ...[
                    ProjectAvatar(
                      project: project,
                      controller: appearanceController,
                      size: 20,
                      borderRadius: 6,
                      emojiFontSize: 14,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      project?.title ?? 'Без проекта',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  if (note.pinned)
                    const Icon(Icons.push_pin_rounded, size: 16),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                note.title,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              if (!compact) ...[
                const SizedBox(height: 4),
                Text(
                  snippet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const Spacer(),
              Text(
                'Изменено ${MaterialLocalizations.of(context).formatCompactDate(note.updatedAt)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentNoteTile extends StatelessWidget {
  const _RecentNoteTile({
    required this.store,
    required this.note,
    required this.onTap,
  });

  final AppStore store;
  final Note note;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final project = store.projectById(note.projectId);
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(child: Text(noteTypeIcon(note.noteType))),
      title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${project?.emoji ?? '📁'} ${project?.title ?? 'Без проекта'} · '
        '${MaterialLocalizations.of(context).formatCompactDate(note.updatedAt)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

IconData _sectionIcon(NoteHomeSection section) {
  return switch (section) {
    NoteHomeSection.continueWork => Icons.play_circle_outline_rounded,
    NoteHomeSection.pinned => Icons.push_pin_outlined,
    NoteHomeSection.recent => Icons.history_rounded,
    NoteHomeSection.projects => Icons.folder_copy_outlined,
    NoteHomeSection.folders => Icons.account_tree_outlined,
    NoteHomeSection.templates => Icons.auto_awesome_outlined,
  };
}

String _plainSnippet(String source) {
  var value = source
      .replaceAll(RegExp(r'```[\s\S]*?```'), ' ')
      .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
  value = value.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (match) => match.group(1) ?? '',
  );
  value = value
      .replaceAll(RegExp(r'[#>*_`~|\[\]{}]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return value.isEmpty ? 'Пустая заметка' : value;
}
