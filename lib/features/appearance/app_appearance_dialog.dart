import 'package:flutter/material.dart';

import 'app_appearance.dart';
import 'app_appearance_theme.dart';

class AppAppearanceDialog extends StatefulWidget {
  const AppAppearanceDialog({
    super.key,
    required this.initialPreferences,
  });

  final AppAppearancePreferences initialPreferences;

  static Future<AppAppearancePreferences?> show(
    BuildContext context, {
    required AppAppearancePreferences preferences,
  }) {
    return showDialog<AppAppearancePreferences>(
      context: context,
      builder: (context) => AppAppearanceDialog(
        initialPreferences: preferences,
      ),
    );
  }

  @override
  State<AppAppearanceDialog> createState() => _AppAppearanceDialogState();
}

class _AppAppearanceDialogState extends State<AppAppearanceDialog> {
  late AppAppearancePreferences draft;

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
        width: 980,
        height: 690,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;
            if (compact) {
              return ListView(
                children: <Widget>[
                  _settings(),
                  const SizedBox(height: 24),
                  _preview(),
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
            setState(() => draft = AppAppearancePreferences.defaults());
          },
          icon: const Icon(Icons.restart_alt_rounded),
          label: const Text('По умолчанию'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, draft),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Применить'),
        ),
      ],
    );
  }

  Widget _settings() {
    return ListView(
      padding: const EdgeInsets.only(right: 6),
      children: <Widget>[
        Text(
          'Готовые темы',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Тема согласованно меняет акцент, иконки, фон и панели. Ниже каждый цвет можно переопределить отдельно.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            for (final palette in ChroniclePalette.values)
              _presetChip(palette),
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
          title: 'Фон приложения',
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

  Widget _presetChip(ChroniclePalette palette) {
    final selected = draft.usesCoordinatedPalette &&
        draft.accentPalette == palette;
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
              Icon(
                switch (style) {
                  ChronicleSurfaceStyle.matte => Icons.crop_square_rounded,
                  ChronicleSurfaceStyle.glossy => Icons.gradient_rounded,
                  ChronicleSurfaceStyle.shiny => Icons.auto_awesome_rounded,
                },
              ),
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
                          color: selected == palette
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
    final previewTheme = buildChronicleTheme(brightness, draft);
    return Theme(
      data: previewTheme,
      child: Builder(
        builder: (previewContext) {
          final colors = Theme.of(previewContext).colorScheme;
          return ColoredBox(
            color: Theme.of(previewContext).scaffoldBackgroundColor,
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
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.science_rounded,
                            color: Theme.of(previewContext)
                                .extension<ChronicleAppearanceTheme>()
                                ?.iconAccent,
                          ),
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
                                  style: Theme.of(previewContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.more_horiz_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
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
                          Text(
                            'Сравнение метастабильных состояний белка и текущие наблюдения.',
                            style: Theme.of(previewContext).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const <Widget>[
                              Chip(label: Text('ORF9b')),
                              Chip(label: Text('MD')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                            FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.palette_rounded),
                    label: const Text('Акцентная кнопка'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Настройки применяются ко всему интерфейсу и не меняют данные проектов.',
                    textAlign: TextAlign.center,
                    style: Theme.of(previewContext).textTheme.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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
          BoxShadow(
            color: color.withValues(alpha: 0.28),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }
}
