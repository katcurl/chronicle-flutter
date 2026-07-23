import 'package:flutter/material.dart';

import 'app_appearance.dart';
import 'app_appearance_store.dart';
import 'app_appearance_theme.dart';

class AppAppearanceDialog extends StatefulWidget {
  const AppAppearanceDialog({
    super.key,
    required this.initialPreferences,
    this.existingBackgroundImage,
  });

  final AppAppearancePreferences initialPreferences;
  final ImageProvider<Object>? existingBackgroundImage;

  static Future<AppAppearanceChange?> show(
    BuildContext context, {
    required AppAppearancePreferences preferences,
    ImageProvider<Object>? existingBackgroundImage,
  }) {
    return showDialog<AppAppearanceChange>(
      context: context,
      builder:
          (context) => AppAppearanceDialog(
            initialPreferences: preferences,
            existingBackgroundImage: existingBackgroundImage,
          ),
    );
  }

  @override
  State<AppAppearanceDialog> createState() => _AppAppearanceDialogState();
}

class _AppAppearanceDialogState extends State<AppAppearanceDialog> {
  late AppAppearancePreferences draft;
  AppBackgroundSelection? pendingBackground;
  bool removeBackground = false;
  bool pickingBackground = false;

  ImageProvider<Object>? get previewBackground {
    final pending = pendingBackground;
    if (pending != null) return MemoryImage(pending.bytes);
    if (removeBackground) return null;
    return widget.existingBackgroundImage;
  }

  @override
  void initState() {
    super.initState();
    draft = widget.initialPreferences;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.all(20),
      title: const Text('Внешний вид Chronicle'),
      content: SizedBox(
        width: 1040,
        height: 720,
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 780) {
              return ListView(
                children: <Widget>[
                  _settings(),
                  const SizedBox(height: 24),
                  SizedBox(height: 560, child: _preview()),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(flex: 6, child: _settings()),
                const VerticalDivider(width: 32),
                Expanded(flex: 5, child: _preview()),
              ],
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () {
            setState(() {
              draft = AppAppearancePreferences.defaults();
              pendingBackground = null;
              removeBackground = true;
            });
          },
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('По умолчанию'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed:
              () => Navigator.pop(
                context,
                AppAppearanceChange(
                  preferences: draft,
                  background: pendingBackground,
                  removeBackground: removeBackground,
                ),
              ),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Применить'),
        ),
      ],
    );
  }

  Widget _settings() {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.only(right: 6),
      children: <Widget>[
        _sectionTitle('Готовые темы'),
        const SizedBox(height: 6),
        Text(
          'Тема согласованно меняет акцент, иконки, фон и панели. Каждый параметр можно переопределить ниже.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final palette in ChroniclePalette.values) _presetChip(palette),
          ],
        ),
        const SizedBox(height: 26),
        _sectionTitle('Режим яркости'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final mode in ChronicleBrightnessMode.values)
              ChoiceChip(
                label: Text(mode.label),
                selected: draft.brightnessMode == mode,
                onSelected: (_) {
                  setState(() => draft = draft.copyWith(brightnessMode: mode));
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        _sectionTitle('Поверхности'),
        const SizedBox(height: 10),
        for (final style in ChronicleSurfaceStyle.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _styleTile(style),
          ),
        const SizedBox(height: 20),
        _backgroundSection(),
        const SizedBox(height: 24),
        _sectionTitle('Стекло и прозрачность'),
        const SizedBox(height: 4),
        _slider(
          title: 'Прозрачность панелей',
          value: draft.panelOpacity,
          minimum: 0.35,
          maximum: 1,
          divisions: 13,
          label: '${(draft.panelOpacity * 100).round()}%',
          onChanged: (value) {
            setState(() => draft = draft.copyWith(panelOpacity: value));
          },
        ),
        _slider(
          title: 'Размытие за панелями',
          value: draft.panelBlurSigma,
          minimum: 0,
          maximum: 30,
          divisions: 15,
          label:
              draft.panelBlurSigma == 0
                  ? 'выкл.'
                  : draft.panelBlurSigma.toStringAsFixed(0),
          onChanged:
              draft.panelOpacity >= 0.999
                  ? null
                  : (value) {
                    setState(
                      () => draft = draft.copyWith(panelBlurSigma: value),
                    );
                  },
        ),
        if (draft.surfaceStyle == ChronicleSurfaceStyle.shiny)
          _slider(
            title: 'Интенсивность блёсток',
            value: draft.sparkleIntensity,
            minimum: 0,
            maximum: 2,
            divisions: 20,
            label: '${(draft.sparkleIntensity * 100).round()}%',
            onChanged: (value) {
              setState(() => draft = draft.copyWith(sparkleIntensity: value));
            },
          ),
        const SizedBox(height: 18),
        _paletteSelector(
          title: 'Акцент и кнопки',
          selected: draft.accentPalette,
          onChanged: (value) {
            setState(() => draft = draft.copyWith(accentPalette: value));
          },
        ),
        _paletteSelector(
          title: 'Активные иконки',
          selected: draft.iconPalette,
          onChanged: (value) {
            setState(() => draft = draft.copyWith(iconPalette: value));
          },
        ),
        _paletteSelector(
          title: 'Фоновый цвет',
          selected: draft.backgroundPalette,
          onChanged: (value) {
            setState(() => draft = draft.copyWith(backgroundPalette: value));
          },
        ),
        _paletteSelector(
          title: 'Панели и карточки',
          selected: draft.panelPalette,
          onChanged: (value) {
            setState(() => draft = draft.copyWith(panelPalette: value));
          },
        ),
      ],
    );
  }

  Widget _backgroundSection() {
    final colors = Theme.of(context).colorScheme;
    final hasBackground = previewBackground != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _sectionTitle('Фоновое изображение или GIF'),
        const SizedBox(height: 6),
        Text(
          'PNG, JPEG, WebP или GIF до 30 МБ. Файл копируется в локальное хранилище Chronicle.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: pickingBackground ? null : _pickBackground,
              icon:
                  pickingBackground
                      ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.wallpaper_rounded),
              label: Text(hasBackground ? 'Заменить фон' : 'Выбрать фон'),
            ),
            if (hasBackground) ...<Widget>[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    pendingBackground = null;
                    removeBackground = true;
                  });
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Убрать'),
              ),
            ],
          ],
        ),
        if (hasBackground) ...<Widget>[
          const SizedBox(height: 10),
          _slider(
            title: 'Яркость изображения',
            value: draft.wallpaperOpacity,
            minimum: 0.1,
            maximum: 1,
            divisions: 18,
            label: '${(draft.wallpaperOpacity * 100).round()}%',
            onChanged: (value) {
              setState(() => draft = draft.copyWith(wallpaperOpacity: value));
            },
          ),
          _slider(
            title: 'Цветовая вуаль',
            value: draft.wallpaperOverlay,
            minimum: 0,
            maximum: 0.85,
            divisions: 17,
            label: '${(draft.wallpaperOverlay * 100).round()}%',
            onChanged: (value) {
              setState(() => draft = draft.copyWith(wallpaperOverlay: value));
            },
          ),
        ],
      ],
    );
  }

  Widget _presetChip(ChroniclePalette palette) {
    final selected =
        draft.usesCoordinatedPalette && draft.accentPalette == palette;
    return FilterChip(
      selected: selected,
      avatar: _colorDot(palette.seed, size: 18),
      label: Text(palette.label),
      onSelected: (_) {
        setState(() {
          draft = AppAppearancePreferences.preset(
            palette,
            surfaceStyle: draft.surfaceStyle,
            brightnessMode: draft.brightnessMode,
            backgroundFileName: draft.backgroundFileName,
            backgroundRevision: draft.backgroundRevision,
            wallpaperOpacity: draft.wallpaperOpacity,
            wallpaperOverlay: draft.wallpaperOverlay,
            panelOpacity: draft.panelOpacity,
            panelBlurSigma: draft.panelBlurSigma,
            sparkleIntensity: draft.sparkleIntensity,
          );
        });
      },
    );
  }

  Widget _styleTile(ChronicleSurfaceStyle style) {
    final colors = Theme.of(context).colorScheme;
    final selected = draft.surfaceStyle == style;
    return Material(
      color: selected ? colors.secondaryContainer : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() => draft = draft.copyWith(surfaceStyle: style));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Icon(switch (style) {
                ChronicleSurfaceStyle.matte => Icons.crop_square_rounded,
                ChronicleSurfaceStyle.glossy => Icons.gradient_rounded,
                ChronicleSurfaceStyle.shiny => Icons.auto_awesome_rounded,
              }),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      style.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      style.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) const Icon(Icons.check_circle_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slider({
    required String title,
    required double value,
    required double minimum,
    required double maximum,
    required int divisions,
    required String label,
    required ValueChanged<double>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(title)),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
          Slider(
            value: value.clamp(minimum, maximum).toDouble(),
            min: minimum,
            max: maximum,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _paletteSelector({
    required String title,
    required ChroniclePalette selected,
    required ValueChanged<ChroniclePalette> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: _sectionTitle(title)),
              Text(
                selected.label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final palette in ChroniclePalette.values)
                Tooltip(
                  message: palette.label,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onChanged(palette),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 34,
                      height: 34,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              selected == palette
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: _colorDot(palette.seed),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _preview() {
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final brightness = switch (draft.brightnessMode) {
      ChronicleBrightnessMode.light => Brightness.light,
      ChronicleBrightnessMode.dark => Brightness.dark,
      ChronicleBrightnessMode.system => platformBrightness,
    };
    final background = previewBackground;
    final previewTheme = buildChronicleTheme(
      brightness,
      draft,
      backgroundAvailable: background != null,
    );
    return Theme(
      data: previewTheme,
      child: Builder(
        builder: (previewContext) {
          final colors = Theme.of(previewContext).colorScheme;
          return ChronicleBackdrop(
            backgroundImage: background,
            revision: draft.backgroundRevision,
            child: ColoredBox(
              color:
                  background == null
                      ? Theme.of(previewContext).scaffoldBackgroundColor
                      : Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Предпросмотр',
                      style: Theme.of(previewContext).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 16),
                    ChroniclePanelSurface(
                      emphasized: true,
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: <Widget>[
                            const Icon(Icons.science_rounded),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    'Проект ORF9b',
                                    style: Theme.of(previewContext)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  Text(
                                    'Активное исследование',
                                    style: Theme.of(
                                      previewContext,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.auto_awesome_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ChroniclePanelSurface(
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'RMSD analysis',
                              style: Theme.of(previewContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Сравнение метастабильных состояний белка и текущие наблюдения.',
                            ),
                            const SizedBox(height: 14),
                            const Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                Chip(label: Text('ORF9b')),
                                Chip(label: Text('MD')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.palette_rounded),
                      label: const Text('Акцентная кнопка'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Фон и эффекты хранятся локально и не меняют данные проектов.',
                      textAlign: TextAlign.center,
                      style: Theme.of(previewContext).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickBackground() async {
    setState(() => pickingBackground = true);
    try {
      final selected = await pickAppBackground();
      if (!mounted || selected == null) return;
      setState(() {
        pendingBackground = selected;
        removeBackground = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить фон: $error')),
      );
    } finally {
      if (mounted) setState(() => pickingBackground = false);
    }
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _colorDot(Color color, {double size = 26}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 6),
        ],
      ),
    );
  }
}
