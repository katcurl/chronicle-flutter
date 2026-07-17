import 'package:flutter/material.dart';

import 'note_image_syntax.dart';

class NoteImageEditorDialog extends StatefulWidget {
  const NoteImageEditorDialog({
    super.key,
    required this.initial,
    required this.imageLabel,
  });

  final NoteImagePresentation initial;
  final String imageLabel;

  static Future<NoteImagePresentation?> show(
    BuildContext context, {
    required NoteImagePresentation initial,
    required String imageLabel,
  }) {
    return showDialog<NoteImagePresentation>(
      context: context,
      builder:
          (context) => NoteImageEditorDialog(
            initial: initial,
            imageLabel: imageLabel,
          ),
    );
  }

  @override
  State<NoteImageEditorDialog> createState() =>
      _NoteImageEditorDialogState();
}

class _NoteImageEditorDialogState extends State<NoteImageEditorDialog> {
  late double widthPercent;
  late NoteImageAlignment alignment;
  late final TextEditingController captionController;

  @override
  void initState() {
    super.initState();
    widthPercent = widget.initial.widthPercent.toDouble();
    alignment = widget.initial.alignment;
    captionController = TextEditingController(text: widget.initial.caption);
  }

  @override
  void dispose() {
    captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roundedWidth = (widthPercent / 5).round() * 5;

    return AlertDialog(
      title: const Text('Настроить изображение'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.imageLabel.isEmpty
                    ? 'Изображение'
                    : widget.imageLabel,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Text(
                    'Размер',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text('$roundedWidth%'),
                ],
              ),
              Slider(
                value: widthPercent,
                min: 20,
                max: 100,
                divisions: 16,
                label: '$roundedWidth%',
                onChanged: (value) => setState(() => widthPercent = value),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in const [25, 50, 75, 100])
                    ChoiceChip(
                      label: Text('$value%'),
                      selected: roundedWidth == value,
                      onSelected:
                          (_) => setState(
                            () => widthPercent = value.toDouble(),
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'Выравнивание',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              SegmentedButton<NoteImageAlignment>(
                segments: const <ButtonSegment<NoteImageAlignment>>[
                  ButtonSegment<NoteImageAlignment>(
                    value: NoteImageAlignment.left,
                    icon: Icon(Icons.format_align_left_rounded),
                    label: Text('Слева'),
                  ),
                  ButtonSegment<NoteImageAlignment>(
                    value: NoteImageAlignment.center,
                    icon: Icon(Icons.format_align_center_rounded),
                    label: Text('По центру'),
                  ),
                  ButtonSegment<NoteImageAlignment>(
                    value: NoteImageAlignment.right,
                    icon: Icon(Icons.format_align_right_rounded),
                    label: Text('Справа'),
                  ),
                ],
                selected: <NoteImageAlignment>{alignment},
                onSelectionChanged:
                    (selected) => setState(() => alignment = selected.first),
              ),
              const SizedBox(height: 22),
              TextField(
                controller: captionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Подпись под изображением',
                  hintText: 'Необязательно',
                  prefixIcon: Icon(Icons.short_text_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'В предпросмотре размер также можно менять, перетаскивая маркер в правом нижнем углу изображения.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(
              context,
              NoteImagePresentation(
                widthPercent: roundedWidth.clamp(20, 100).toInt(),
                alignment: alignment,
                caption: captionController.text.trim(),
              ),
            );
          },
          child: const Text('Применить'),
        ),
      ],
    );
  }
}
