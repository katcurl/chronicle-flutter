import 'package:flutter/material.dart';

import '../appearance/app_appearance.dart';
import '../appearance/app_appearance_theme.dart';
import '../workspaces/workspace_profile.dart';

enum AppSettingsDestination {
  appearance,
  workspaces,
  projectAppearance,
  reliability,
}

class AppSettingsDialog extends StatelessWidget {
  const AppSettingsDialog({
    super.key,
    required this.appearance,
    required this.activeWorkspace,
  });

  final AppAppearancePreferences appearance;
  final WorkspaceProfile activeWorkspace;

  static Future<AppSettingsDestination?> show(
    BuildContext context, {
    required AppAppearancePreferences appearance,
    required WorkspaceProfile activeWorkspace,
  }) {
    return showDialog<AppSettingsDestination>(
      context: context,
      builder:
          (context) => AppSettingsDialog(
            appearance: appearance,
            activeWorkspace: activeWorkspace,
          ),
    );
  }

  static String appearanceSummary(AppAppearancePreferences appearance) {
    final background = appearance.hasBackgroundImage ? 'с фоном' : 'без фона';
    final glass =
        appearance.panelOpacity < 0.999
            ? 'стекло ${(appearance.panelOpacity * 100).round()}%'
            : appearance.surfaceStyle.label;
    return '${appearance.accentPalette.label} · $glass · $background · '
        '${appearance.brightnessMode.label}';
  }

  static String workspaceSummary(WorkspaceProfile workspace) {
    return '${workspace.emoji} ${workspace.name} · '
        'старт: ${workspace.startSection.label}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.settings_rounded),
          SizedBox(width: 12),
          Text('Настройки Chronicle'),
        ],
      ),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Персонализация',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _SettingsRow(
                icon: Icons.palette_outlined,
                title: 'Внешний вид',
                subtitle: appearanceSummary(appearance),
                accent: appearance.accentPalette.seed,
                onTap:
                    () => Navigator.pop(
                      context,
                      AppSettingsDestination.appearance,
                    ),
              ),
              const SizedBox(height: 10),
              _SettingsRow(
                icon: Icons.dashboard_customize_outlined,
                title: 'Рабочие пространства',
                subtitle: workspaceSummary(activeWorkspace),
                onTap:
                    () => Navigator.pop(
                      context,
                      AppSettingsDestination.workspaces,
                    ),
              ),
              const SizedBox(height: 10),
              _SettingsRow(
                icon: Icons.folder_special_outlined,
                title: 'Оформление проектов',
                subtitle:
                    'Темы и изображения/GIF задаются в настройках проекта.',
                onTap:
                    () => Navigator.pop(
                      context,
                      AppSettingsDestination.projectAppearance,
                    ),
              ),
              const SizedBox(height: 10),
              _SettingsRow(
                icon: Icons.verified_user_outlined,
                title: 'Надёжность и восстановление',
                subtitle:
                    'Проверка целостности, Vault, backup round-trip и undo.',
                onTap:
                    () => Navigator.pop(
                      context,
                      AppSettingsDestination.reliability,
                    ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Настройки интерфейса хранятся локально и не меняют '
                      'заметки, проекты, Vault или синхронизацию.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
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

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(16);
    final accentColor = accent;
    return ChroniclePanelSurface(
      borderRadius: radius,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(icon, color: colors.onPrimaryContainer),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (accentColor != null) ...[
                  const SizedBox(width: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: colors.outlineVariant,
                        width: 1.5,
                      ),
                    ),
                    child: const SizedBox(width: 16, height: 16),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
