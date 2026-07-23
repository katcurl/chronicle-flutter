import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../appearance/app_appearance.dart';
import '../appearance/app_appearance_theme.dart';
import 'project_appearance_store.dart';

class ProjectAppearanceScope extends StatelessWidget {
  const ProjectAppearanceScope({
    super.key,
    required this.projectId,
    required this.controller,
    required this.globalAppearance,
    required this.child,
  });

  final String projectId;
  final ProjectAppearanceController controller;
  final AppAppearancePreferences globalAppearance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final preferences = controller.preferencesFor(projectId);
        if (preferences.inheritsGlobal) return child!;
        final appearance = preferences.effectiveAppearance(globalAppearance);
        final backgroundFile = controller.backgroundFileFor(projectId);
        final brightness = Theme.of(context).brightness;
        return Theme(
          data: buildChronicleTheme(
            brightness,
            appearance,
            backgroundAvailable: backgroundFile != null,
          ),
          child: ChronicleBackdrop(
            backgroundImage:
                backgroundFile == null ? null : FileImage(backgroundFile),
            revision: preferences.backgroundRevision,
            child: child!,
          ),
        );
      },
      child: child,
    );
  }
}

class ProjectSurface extends StatelessWidget {
  const ProjectSurface({
    super.key,
    required this.child,
    this.tint,
    this.emphasized = false,
    this.borderRadius = 22,
  });

  final Widget child;
  final Color? tint;
  final bool emphasized;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ChroniclePanelSurface(
      emphasized: emphasized,
      borderRadius: BorderRadius.circular(borderRadius),
      child: ColoredBox(color: tint ?? Colors.transparent, child: child),
    );
  }
}

class ProjectAvatar extends StatelessWidget {
  const ProjectAvatar({
    super.key,
    required this.project,
    required this.controller,
    this.size = 48,
    this.borderRadius = 15,
    this.backgroundColor,
    this.emojiFontSize,
    this.fallbackEmoji,
  });

  final Project project;
  final ProjectAppearanceController controller;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final double? emojiFontSize;
  final String? fallbackEmoji;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final file = controller.iconFileFor(project.id);
        final fallback = _fallback();
        return Container(
          width: size,
          height: size,
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                backgroundColor ??
                Color(project.colorValue).withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child:
              file == null
                  ? fallback
                  : Image.file(
                    file,
                    key: ValueKey<String>(
                      '${file.path}:${controller.preferencesFor(project.id).iconRevision}',
                    ),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (_, __, ___) => fallback,
                  ),
        );
      },
    );
  }

  Widget _fallback() {
    return Text(
      fallbackEmoji ?? project.emoji,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: emojiFontSize ?? size * 0.54),
    );
  }
}
