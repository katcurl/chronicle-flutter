import '../appearance/app_appearance.dart';

class ProjectAppearancePreferences {
  const ProjectAppearancePreferences({
    required this.inheritsGlobal,
    required this.accentPalette,
    required this.iconPalette,
    required this.backgroundPalette,
    required this.panelPalette,
    required this.surfaceStyle,
    this.iconFileName,
    this.iconRevision = 0,
  });

  final bool inheritsGlobal;
  final ChroniclePalette accentPalette;
  final ChroniclePalette iconPalette;
  final ChroniclePalette backgroundPalette;
  final ChroniclePalette panelPalette;
  final ChronicleSurfaceStyle surfaceStyle;
  final String? iconFileName;
  final int iconRevision;

  factory ProjectAppearancePreferences.defaults() {
    return const ProjectAppearancePreferences(
      inheritsGlobal: true,
      accentPalette: ChroniclePalette.violet,
      iconPalette: ChroniclePalette.violet,
      backgroundPalette: ChroniclePalette.violet,
      panelPalette: ChroniclePalette.violet,
      surfaceStyle: ChronicleSurfaceStyle.matte,
    );
  }

  factory ProjectAppearancePreferences.fromAppearance(
    AppAppearancePreferences appearance, {
    bool inheritsGlobal = true,
  }) {
    return ProjectAppearancePreferences(
      inheritsGlobal: inheritsGlobal,
      accentPalette: appearance.accentPalette,
      iconPalette: appearance.iconPalette,
      backgroundPalette: appearance.backgroundPalette,
      panelPalette: appearance.panelPalette,
      surfaceStyle: appearance.surfaceStyle,
    );
  }

  bool get usesCoordinatedPalette =>
      accentPalette == iconPalette &&
      accentPalette == backgroundPalette &&
      accentPalette == panelPalette;

  AppAppearancePreferences effectiveAppearance(
    AppAppearancePreferences globalAppearance,
  ) {
    if (inheritsGlobal) return globalAppearance;
    return AppAppearancePreferences(
      accentPalette: accentPalette,
      iconPalette: iconPalette,
      backgroundPalette: backgroundPalette,
      panelPalette: panelPalette,
      surfaceStyle: surfaceStyle,
      brightnessMode: globalAppearance.brightnessMode,
    );
  }

  ProjectAppearancePreferences withPreset(ChroniclePalette palette) {
    return copyWith(
      accentPalette: palette,
      iconPalette: palette,
      backgroundPalette: palette,
      panelPalette: palette,
    );
  }

  ProjectAppearancePreferences copyWith({
    bool? inheritsGlobal,
    ChroniclePalette? accentPalette,
    ChroniclePalette? iconPalette,
    ChroniclePalette? backgroundPalette,
    ChroniclePalette? panelPalette,
    ChronicleSurfaceStyle? surfaceStyle,
    String? iconFileName,
    bool clearIconFileName = false,
    int? iconRevision,
  }) {
    return ProjectAppearancePreferences(
      inheritsGlobal: inheritsGlobal ?? this.inheritsGlobal,
      accentPalette: accentPalette ?? this.accentPalette,
      iconPalette: iconPalette ?? this.iconPalette,
      backgroundPalette: backgroundPalette ?? this.backgroundPalette,
      panelPalette: panelPalette ?? this.panelPalette,
      surfaceStyle: surfaceStyle ?? this.surfaceStyle,
      iconFileName:
          clearIconFileName ? null : iconFileName ?? this.iconFileName,
      iconRevision: iconRevision ?? this.iconRevision,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'inheritsGlobal': inheritsGlobal,
    'accentPalette': accentPalette.id,
    'iconPalette': iconPalette.id,
    'backgroundPalette': backgroundPalette.id,
    'panelPalette': panelPalette.id,
    'surfaceStyle': surfaceStyle.id,
    'iconFileName': iconFileName,
    'iconRevision': iconRevision,
  };

  factory ProjectAppearancePreferences.fromJson(Map<String, Object?> json) {
    final rawInheritsGlobal = json['inheritsGlobal'];
    final rawRevision = json['iconRevision'];
    final legacyPalette = ChroniclePalette.fromId(json['palette']);
    final accentPalette = ChroniclePalette.fromId(
      json['accentPalette'],
      fallback: legacyPalette,
    );
    return ProjectAppearancePreferences(
      inheritsGlobal: rawInheritsGlobal is bool ? rawInheritsGlobal : true,
      accentPalette: accentPalette,
      iconPalette: ChroniclePalette.fromId(
        json['iconPalette'],
        fallback: accentPalette,
      ),
      backgroundPalette: ChroniclePalette.fromId(
        json['backgroundPalette'],
        fallback: accentPalette,
      ),
      panelPalette: ChroniclePalette.fromId(
        json['panelPalette'],
        fallback: accentPalette,
      ),
      surfaceStyle: ChronicleSurfaceStyle.fromId(json['surfaceStyle']),
      iconFileName: _cleanOptionalText(json['iconFileName']),
      iconRevision: rawRevision is int
          ? rawRevision
          : int.tryParse(rawRevision?.toString() ?? '') ?? 0,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ProjectAppearancePreferences &&
            inheritsGlobal == other.inheritsGlobal &&
            accentPalette == other.accentPalette &&
            iconPalette == other.iconPalette &&
            backgroundPalette == other.backgroundPalette &&
            panelPalette == other.panelPalette &&
            surfaceStyle == other.surfaceStyle &&
            iconFileName == other.iconFileName &&
            iconRevision == other.iconRevision;
  }

  @override
  int get hashCode => Object.hash(
    inheritsGlobal,
    accentPalette,
    iconPalette,
    backgroundPalette,
    panelPalette,
    surfaceStyle,
    iconFileName,
    iconRevision,
  );
}

String? _cleanOptionalText(Object? raw) {
  final value = raw?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}
