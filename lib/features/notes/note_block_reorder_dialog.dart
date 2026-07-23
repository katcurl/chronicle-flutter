import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'note_block_syntax.dart';

class NoteBlockReorderDialog extends StatefulWidget {
  const NoteBlockReorderDialog({
    super.key,
    required this.blocks,
    this.selectedBlockIndex,
  });

  final List<NoteBlockReference> blocks;
  final int? selectedBlockIndex;

  static Future<List<int>?> show(
    BuildContext context, {
    required String source,
    int? selectedBlockIndex,
  }) {
    final blocks = NoteBlockSyntax.all(source);
    return showDialog<List<int>>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => NoteBlockReorderDialog(
            blocks: blocks,
            selectedBlockIndex: selectedBlockIndex,
          ),
    );
  }

  @override
  State<NoteBlockReorderDialog> createState() => _NoteBlockReorderDialogState();
}

class _NoteBlockReorderDialogState extends State<NoteBlockReorderDialog> {
  late final List<_ReorderEntry> _entries;

  @override
  void initState() {
    super.initState();
    _entries = [
      for (final block in widget.blocks)
        _ReorderEntry(originalIndex: block.index, block: block),
    ];
  }

  bool get _changed {
    for (var index = 0; index < _entries.length; index += 1) {
      if (_entries[index].originalIndex != index) {
        return true;
      }
    }
    return false;
  }

  bool get _useDelayedHandle => switch (defaultTargetPlatform) {
    TargetPlatform.android || TargetPlatform.iOS => true,
    _ => false,
  };

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = (screen.width - 96).clamp(260.0, 680.0).toDouble();
    final dialogHeight = (screen.height - 240).clamp(280.0, 620.0).toDouble();

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.drag_indicator_rounded),
          SizedBox(width: 10),
          Expanded(child: Text('Порядок блоков')),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _useDelayedHandle
                  ? 'Удерживай ручку блока и перетаскивай его. Изменение '
                      'применится только после нажатия «Готово».'
                  : 'Перетаскивай блок за ручку. Изменение применится только '
                      'после нажатия «Готово».',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _entries.length,
                onReorderItem: _reorderItem,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(12),
                    child: child,
                  );
                },
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final selected =
                      entry.originalIndex == widget.selectedBlockIndex;
                  return Card(
                    key: ValueKey<int>(entry.originalIndex),
                    margin: const EdgeInsets.only(bottom: 8),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      selected: selected,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text('${index + 1}'),
                      ),
                      title: Text(entry.block.label),
                      subtitle: Text(
                        _preview(entry.block),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Tooltip(
                        message:
                            _useDelayedHandle
                                ? 'Удерживай и перетаскивай'
                                : 'Перетаскивай блок',
                        child: _dragHandle(index),
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
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed:
              _changed
                  ? () => Navigator.pop(context, [
                    for (final entry in _entries) entry.originalIndex,
                  ])
                  : null,
          child: const Text('Готово'),
        ),
      ],
    );
  }

  Widget _dragHandle(int index) {
    const child = Padding(
      padding: EdgeInsets.all(10),
      child: Icon(Icons.drag_handle_rounded),
    );
    if (_useDelayedHandle) {
      return ReorderableDelayedDragStartListener(index: index, child: child);
    }
    return ReorderableDragStartListener(index: index, child: child);
  }

  void _reorderItem(int oldIndex, int newIndex) {
    if (newIndex == oldIndex) {
      return;
    }
    setState(() {
      final entry = _entries.removeAt(oldIndex);
      _entries.insert(newIndex, entry);
    });
  }

  String _preview(NoteBlockReference block) {
    final compact = block.raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) {
      return 'Пустой блок';
    }
    if (compact.length <= 120) {
      return compact;
    }
    return '${compact.substring(0, 117)}…';
  }
}

class _ReorderEntry {
  const _ReorderEntry({required this.originalIndex, required this.block});

  final int originalIndex;
  final NoteBlockReference block;
}
