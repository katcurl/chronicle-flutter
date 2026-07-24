part of 'notes_screen.dart';

class _CitationPickerDialog extends StatefulWidget {
  const _CitationPickerDialog({required this.sources});

  final List<CitationSource> sources;

  @override
  State<_CitationPickerDialog> createState() => _CitationPickerDialogState();
}

class _CitationPickerDialogState extends State<_CitationPickerDialog> {
  String query = '';
  final Set<String> selectedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final normalized = query.trim().toLowerCase();
    final sources =
        widget.sources.where((source) {
            if (normalized.isEmpty) return true;
            return [
              source.citationKey,
              source.title,
              source.authors.join(' '),
              source.containerTitle,
              source.doi,
            ].join(' ').toLowerCase().contains(normalized);
          }).toList()
          ..sort(
            (left, right) => left.citationKey.toLowerCase().compareTo(
              right.citationKey.toLowerCase(),
            ),
          );

    return AlertDialog(
      title: const Text('Вставить цитату'),
      content: SizedBox(
        width: 680,
        height: 520,
        child: Column(
          children: [
            SearchBar(
              hintText: 'Citation key, название или автор',
              leading: const Icon(Icons.search_rounded),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  sources.isEmpty
                      ? const Center(child: Text('Источники не найдены'))
                      : ListView.builder(
                        itemCount: sources.length,
                        itemBuilder: (context, index) {
                          final source = sources[index];
                          final selected = selectedIds.contains(source.id);
                          final subtitleParts = <String>[
                            '@${source.citationKey}',
                            if (source.year != null) source.year.toString(),
                            if (source.authors.isNotEmpty) source.authors.first,
                          ];
                          return CheckboxListTile(
                            value: selected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedIds.add(source.id);
                                } else {
                                  selectedIds.remove(source.id);
                                }
                              });
                            },
                            title: Text(source.title),
                            subtitle: Text(subtitleParts.join(' · ')),
                            secondary: const Icon(Icons.article_outlined),
                            controlAffinity: ListTileControlAffinity.trailing,
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed:
              selectedIds.isEmpty
                  ? null
                  : () => Navigator.pop(context, [
                    for (final source in widget.sources)
                      if (selectedIds.contains(source.id)) source,
                  ]),
          icon: const Icon(Icons.format_quote_rounded),
          label: Text(
            selectedIds.length <= 1
                ? 'Вставить'
                : 'Вставить ${selectedIds.length}',
          ),
        ),
      ],
    );
  }
}

class _WikiLinkSuggestionsBar extends StatelessWidget {
  const _WikiLinkSuggestionsBar({
    required this.controller,
    required this.store,
    required this.currentNoteId,
    required this.sourceProjectId,
    required this.sourceFolderPath,
  });

  final TextEditingController controller;
  final AppStore store;
  final String currentNoteId;
  final String sourceProjectId;
  final String sourceFolderPath;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final value = controller.value;
        if (!value.selection.isValid || !value.selection.isCollapsed) {
          return const SizedBox.shrink();
        }
        final query = NoteWikiLinkSyntax.autocompleteAt(
          value.text,
          value.selection.extentOffset,
        );
        if (query == null) {
          return const SizedBox.shrink();
        }

        final normalized = query.query.toLowerCase();
        final candidates =
            store.data.notes.where((note) => note.id != currentNoteId).where((
              note,
            ) {
              if (normalized.isEmpty) return true;
              final project = store.projectById(note.projectId);
              final searchable =
                  [
                    note.title,
                    note.folderPath,
                    project?.title ?? '',
                  ].join(' ').toLowerCase();
              return searchable.contains(normalized);
            }).toList();
        candidates.sort((left, right) {
          int rank(Note note) {
            final title = note.title.toLowerCase();
            final prefix =
                normalized.isNotEmpty && title.startsWith(normalized);
            if (note.projectId == sourceProjectId &&
                note.folderPath.trim() == sourceFolderPath.trim()) {
              return prefix ? 0 : 1;
            }
            if (note.projectId == sourceProjectId) return prefix ? 2 : 3;
            return prefix ? 4 : 5;
          }

          final rankCompare = rank(left).compareTo(rank(right));
          if (rankCompare != 0) return rankCompare;
          return left.title.toLowerCase().compareTo(right.title.toLowerCase());
        });
        final visible = candidates.take(6).toList(growable: false);
        if (visible.isEmpty) {
          return const SizedBox.shrink();
        }

        return Material(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: SizedBox(
            height: 54,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final note = visible[index];
                final project = store.projectById(note.projectId);
                final duplicateTitle =
                    store.notesByTitle(note.title).length > 1;
                final label =
                    duplicateTitle && project != null
                        ? '${note.title} · ${project.title}'
                        : note.title;
                return Tooltip(
                  message: _noteLocationLabel(store, note),
                  child: ActionChip(
                    avatar: Text(noteTypeIcon(note.noteType)),
                    label: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _complete(query, note),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _complete(NoteWikiAutocompleteQuery query, Note note) {
    final value = controller.value;
    if (query.end > value.text.length) return;
    final target = NoteWikiTarget.exactId(note.id);
    final completion = NoteWikiLinkSyntax.complete(
      value.text,
      query,
      target,
      label: note.title,
    );
    controller.value = value.copyWith(
      text: completion.text,
      selection: TextSelection.collapsed(offset: completion.cursor),
      composing: TextRange.empty,
    );
  }
}

String _wikiTargetDisplayName(String rawTarget) {
  final parsed = NoteWikiTarget.parse(rawTarget);
  return parsed.noteTitle.isEmpty ? rawTarget : parsed.noteTitle;
}

String _noteLocationLabel(AppStore store, Note note) {
  final project = store.projectById(note.projectId);
  return [
    project?.title ?? 'Без проекта',
    if (note.folderPath.trim().isNotEmpty) note.folderPath.trim(),
  ].join(' · ');
}

class _LinkSection extends StatelessWidget {
  const _LinkSection({
    required this.title,
    required this.emptyText,
    required this.links,
    required this.resolve,
    required this.onOpen,
    this.subtitle,
    this.onMissing,
    this.missingActionLabel,
  });

  final String title;
  final String emptyText;
  final List<NoteLink> links;
  final Note? Function(NoteLink link) resolve;
  final String? Function(NoteLink link, Note? note)? subtitle;
  final ValueChanged<Note?> onOpen;
  final ValueChanged<NoteLink>? onMissing;
  final String Function(NoteLink link)? missingActionLabel;

  @override
  Widget build(BuildContext context) {
    return _ContextCard(
      title: title,
      child:
          links.isEmpty
              ? Text(emptyText)
              : Column(children: [for (final link in links) _buildLink(link)]),
    );
  }

  Widget _buildLink(NoteLink link) {
    final note = resolve(link);
    final detail = subtitle?.call(link, note);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        note == null ? Icons.link_off_rounded : Icons.description_outlined,
      ),
      title: Text(note?.title ?? _wikiTargetDisplayName(link.targetTitle)),
      subtitle:
          detail == null || detail.trim().isEmpty
              ? null
              : Text(detail, maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing:
          note == null && onMissing != null
              ? TextButton(
                onPressed: () => onMissing!(link),
                child: Text(missingActionLabel?.call(link) ?? 'Открыть'),
              )
              : const Icon(Icons.chevron_right_rounded),
      onTap:
          note != null
              ? () => onOpen(note)
              : onMissing == null
              ? null
              : () => onMissing!(link),
    );
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.title, required this.child, this.action});

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _PropertyRow extends StatelessWidget {
  const _PropertyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 17),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

enum _WikiRenameDecision { cancel, renameOnly, updateLinks }

class _WikiRenamePreviewDialog extends StatelessWidget {
  const _WikiRenamePreviewDialog({required this.plan});

  final NoteWikiRenamePlan plan;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Безопасное переименование'),
      content: SizedBox(
        width: 620,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '«${plan.oldTitle}» → «${plan.newTitle}»',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Chronicle может обновить ${plan.occurrenceCount} '
                'ссылок в ${plan.changedNoteCount} заметках. Перед операцией '
                'для каждой изменяемой заметки будет сохранена версия.',
              ),
              if (plan.skippedAmbiguousOccurrences > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Не будут изменены неоднозначные ссылки: '
                  '${plan.skippedAmbiguousOccurrences}. Их можно исправить '
                  'через «Проверить ссылки».',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              for (final change in plan.sourceChanges.take(12))
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  leading: const Icon(Icons.description_outlined),
                  title: Text(change.sourceTitle),
                  subtitle: Text('Ссылок: ${change.occurrenceCount}'),
                  children: [
                    for (final occurrence in change.occurrences.take(3))
                      ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.only(left: 16),
                        leading: const Icon(Icons.link_rounded, size: 18),
                        title: Text(
                          occurrence.snippet.isEmpty
                              ? '[[${occurrence.rawTarget}]]'
                              : occurrence.snippet,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              if (plan.sourceChanges.length > 12)
                Text(
                  'И ещё заметок: ${plan.sourceChanges.length - 12}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, _WikiRenameDecision.cancel),
          child: const Text('Отмена'),
        ),
        TextButton(
          onPressed:
              () => Navigator.pop(context, _WikiRenameDecision.renameOnly),
          child: const Text('Только название'),
        ),
        FilledButton.icon(
          onPressed:
              plan.skippedAmbiguousOccurrences > 0
                  ? null
                  : () =>
                      Navigator.pop(context, _WikiRenameDecision.updateLinks),
          icon: const Icon(Icons.link_rounded),
          label: Text(
            plan.skippedAmbiguousOccurrences > 0
                ? 'Сначала исправить неоднозначные'
                : 'Обновить ${plan.occurrenceCount} ссылок',
          ),
        ),
      ],
    );
  }
}

class _LinkHealthSelection {
  const _LinkHealthSelection({required this.issue, required this.repair});

  final NoteWikiLinkIssue issue;
  final bool repair;
}

class _LinkHealthDialog extends StatelessWidget {
  const _LinkHealthDialog({required this.store, required this.issues});

  final AppStore store;
  final List<NoteWikiLinkIssue> issues;

  @override
  Widget build(BuildContext context) {
    final missing =
        issues
            .where((issue) => issue.kind == NoteWikiLinkIssueKind.missing)
            .length;
    final ambiguous = issues.length - missing;
    final dialogHeight =
        (MediaQuery.sizeOf(context).height * 0.62)
            .clamp(300.0, 520.0)
            .toDouble();
    return AlertDialog(
      title: const Text('Проверка связей'),
      content: SizedBox(
        width: 680,
        height: dialogHeight,
        child:
            issues.isEmpty
                ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_outlined, size: 52),
                      SizedBox(height: 10),
                      Text('Все вики-ссылки разрешаются однозначно.'),
                    ],
                  ),
                )
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Не найдены: $missing · Неоднозначны: $ambiguous',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
                        itemCount: issues.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final issue = issues[index];
                          final source = store.noteById(issue.sourceNoteId);
                          final exactMissing =
                              issue.kind == NoteWikiLinkIssueKind.missing &&
                              NoteWikiTarget.parse(issue.rawTarget).noteId !=
                                  null;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              issue.kind == NoteWikiLinkIssueKind.missing
                                  ? Icons.link_off_rounded
                                  : Icons.call_split_rounded,
                            ),
                            title: Text(
                              '[[${issue.rawTarget}]]',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                source?.title ?? issue.sourceTitle,
                                if (issue.snippet.isNotEmpty) issue.snippet,
                              ].join('\n'),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap:
                                () => Navigator.pop(
                                  context,
                                  _LinkHealthSelection(
                                    issue: issue,
                                    repair: false,
                                  ),
                                ),
                            trailing:
                                exactMissing
                                    ? const Tooltip(
                                      message:
                                          'Точная ссылка ведёт на удалённую '
                                          'заметку; открой источник для '
                                          'ручного решения.',
                                      child: Icon(Icons.info_outline_rounded),
                                    )
                                    : TextButton(
                                      onPressed:
                                          () => Navigator.pop(
                                            context,
                                            _LinkHealthSelection(
                                              issue: issue,
                                              repair: true,
                                            ),
                                          ),
                                      child: Text(
                                        issue.kind ==
                                                NoteWikiLinkIssueKind.missing
                                            ? 'Создать'
                                            : 'Выбрать',
                                      ),
                                    ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}
