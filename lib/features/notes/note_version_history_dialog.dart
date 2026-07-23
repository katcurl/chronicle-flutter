import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import 'note_version_diff.dart';

class NoteVersionHistoryDialog extends StatefulWidget {
  const NoteVersionHistoryDialog({
    super.key,
    required this.versions,
    required this.current,
    this.initialVersionId,
  });

  final List<NoteVersion> versions;
  final NoteVersion current;
  final String? initialVersionId;

  static Future<NoteVersion?> show(
    BuildContext context, {
    required List<NoteVersion> versions,
    required NoteVersion current,
    String? initialVersionId,
  }) {
    return showDialog<NoteVersion>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => NoteVersionHistoryDialog(
            versions: versions,
            current: current,
            initialVersionId: initialVersionId,
          ),
    );
  }

  @override
  State<NoteVersionHistoryDialog> createState() =>
      _NoteVersionHistoryDialogState();
}

class _NoteVersionHistoryDialogState extends State<NoteVersionHistoryDialog> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedVersionId;
  final Map<String, NoteVersionDiff> _diffCache = <String, NoteVersionDiff>{};

  @override
  void initState() {
    super.initState();
    final requested = widget.initialVersionId;
    final hasRequested = widget.versions.any(
      (version) => version.id == requested,
    );
    _selectedVersionId =
        hasRequested
            ? requested
            : widget.versions.isEmpty
            ? null
            : widget.versions.first.id;
    _searchController.addListener(_handleSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _handleSearchChanged() {
    setState(() {});
  }

  List<NoteVersion> get _filteredVersions {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.versions;
    }
    return widget.versions
        .where((version) {
          final searchable =
              <String>[
                version.title,
                version.reason,
                version.noteType,
                version.status,
                version.folderPath,
                ...version.tags,
                ...version.properties.keys,
                ...version.properties.values,
                _formatDate(version.createdAt),
              ].join(' ').toLowerCase();
          return searchable.contains(query);
        })
        .toList(growable: false);
  }

  NoteVersion? get _selectedVersion {
    final selectedId = _selectedVersionId;
    if (selectedId == null) {
      return null;
    }
    for (final version in widget.versions) {
      if (version.id == selectedId) {
        return version;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final width = mediaSize.width < 1180 ? mediaSize.width - 32 : 1140.0;
    final height = mediaSize.height < 820 ? mediaSize.height - 32 : 780.0;
    final versions = _filteredVersions;
    final selected = _selectedVersion;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'История версий',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 760) {
                    return Column(
                      children: [
                        SizedBox(
                          height: 240,
                          child: _buildVersionList(context, versions),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: _buildVersionDetails(context, selected),
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(
                        width: 330,
                        child: _buildVersionList(context, versions),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: _buildVersionDetails(context, selected)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionList(BuildContext context, List<NoteVersion> versions) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search_rounded),
              labelText: 'Найти версию',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child:
              versions.isEmpty
                  ? const Center(child: Text('Версии не найдены'))
                  : ListView.builder(
                    itemCount: versions.length,
                    itemBuilder: (context, index) {
                      final version = versions[index];
                      final selected = version.id == _selectedVersionId;
                      return ListTile(
                        selected: selected,
                        leading: const Icon(Icons.history_rounded),
                        title: Text(_formatDate(version.createdAt)),
                        subtitle: Text(
                          version.reason,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap:
                            () =>
                                setState(() => _selectedVersionId = version.id),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget _buildVersionDetails(BuildContext context, NoteVersion? version) {
    if (version == null) {
      return const Center(child: Text('Выбери версию слева'));
    }

    final diff = _diffCache.putIfAbsent(
      version.id,
      () => NoteVersionDiff.compare(version.body, widget.current.body),
    );
    final metadataChanges = _metadataChanges(version, widget.current);
    return DefaultTabController(
      key: ValueKey(version.id),
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(version.createdAt),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(version.reason),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CountChip(
                      icon: Icons.add_rounded,
                      label: '+${diff.addedLineCount}',
                    ),
                    _CountChip(
                      icon: Icons.remove_rounded,
                      label: '−${diff.removedLineCount}',
                    ),
                    _CountChip(
                      icon: Icons.tune_rounded,
                      label: '${metadataChanges.length} метаданных',
                    ),
                  ],
                ),
                if (metadataChanges.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    metadataChanges.join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (diff.isApproximate) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Большая заметка: показано безопасное сравнение общего '
                    'начала и конца; изменённая середина отмечена целиком.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const TabBar(
            tabs: [Tab(text: 'Изменения'), Tab(text: 'Содержимое версии')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _VersionDiffView(diff: diff),
                _VersionSourceView(source: version.body),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Перед восстановлением Chronicle сохранит текущее '
                    'состояние отдельной версией.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () => _confirmRestore(version),
                  icon: const Icon(Icons.restore_rounded),
                  label: const Text('Восстановить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(NoteVersion version) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Восстановить эту версию?'),
            content: Text(
              'Текущая заметка будет заменена состоянием от '
              '${_formatDate(version.createdAt)}. Перед заменой Chronicle '
              'автоматически создаст снимок текущего состояния.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Восстановить'),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, version);
    }
  }

  static List<String> _metadataChanges(
    NoteVersion version,
    NoteVersion current,
  ) {
    final changes = <String>[];
    if (version.title != current.title) changes.add('название');
    if (version.noteType != current.noteType) changes.add('тип');
    if (version.status != current.status) changes.add('статус');
    if (version.folderPath != current.folderPath) changes.add('папка');
    if (!_sameList(version.tags, current.tags)) changes.add('теги');
    if (!_sameMap(version.properties, current.properties)) {
      changes.add('свойства');
    }
    return changes;
  }

  static bool _sameList(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static bool _sameMap(Map<String, String> left, Map<String, String> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  static String _formatDate(DateTime value) {
    return DateFormat('dd.MM.yyyy HH:mm').format(value.toLocal());
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _VersionDiffView extends StatelessWidget {
  const _VersionDiffView({required this.diff});

  final NoteVersionDiff diff;

  @override
  Widget build(BuildContext context) {
    if (!diff.hasChanges) {
      return const Center(child: Text('Текст заметки не изменился'));
    }
    final scheme = Theme.of(context).colorScheme;
    final monospace = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', height: 1.35);
    return SelectionArea(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: diff.lines.length,
        itemBuilder: (context, index) {
          final line = diff.lines[index];
          final marker = switch (line.kind) {
            NoteVersionDiffKind.added => '+',
            NoteVersionDiffKind.removed => '−',
            NoteVersionDiffKind.unchanged => ' ',
          };
          final background = switch (line.kind) {
            NoteVersionDiffKind.added => scheme.primaryContainer.withValues(
              alpha: 0.45,
            ),
            NoteVersionDiffKind.removed => scheme.errorContainer.withValues(
              alpha: 0.45,
            ),
            NoteVersionDiffKind.unchanged => Colors.transparent,
          };
          return Container(
            color: background,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    line.oldLineNumber?.toString() ?? '',
                    textAlign: TextAlign.right,
                    style: monospace,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: Text(
                    line.newLineNumber?.toString() ?? '',
                    textAlign: TextAlign.right,
                    style: monospace,
                  ),
                ),
                const SizedBox(width: 10),
                Text(marker, style: monospace),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    line.text.isEmpty ? ' ' : line.text,
                    style: monospace,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _VersionSourceView extends StatelessWidget {
  const _VersionSourceView({required this.source});

  final String source;

  @override
  Widget build(BuildContext context) {
    return SelectionArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Text(
          source,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontFamily: 'monospace',
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
