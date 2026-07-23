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
    this.backgroundFileName,
    this.backgroundRevision = 0,
    this.wallpaperOpacity = 1,
    this.wallpaperOverlay = 0.18,
    this.panelOpacity = 1,
    this.panelBlurSigma = 0,
    this.sparkleIntensity = 1,
  });

  final bool inheritsGlobal;
  final ChroniclePalette accentPalette;
  final ChroniclePalette iconPalette;
  final ChroniclePalette backgroundPalette;
  final ChroniclePalette panelPalette;
  final ChronicleSurfaceStyle surfaceStyle;
  final String? iconFileName;
  final int iconRevision;
  final String? backgroundFileName;
  final int backgroundRevision;
  final double wallpaperOpacity;
  final double wallpaperOverlay;
  final double panelOpacity;
  final double panelBlurSigma;
  final double sparkleIntensity;

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
      wallpaperOpacity: appearance.wallpaperOpacity,
      wallpaperOverlay: appearance.wallpaperOverlay,
      panelOpacity: appearance.panelOpacity,
      panelBlurSigma: appearance.panelBlurSigma,
      sparkleIntensity: appearance.sparkleIntensity,
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
      backgroundFileName: backgroundFileName,
      backgroundRevision: backgroundRevision,
      wallpaperOpacity: wallpaperOpacity,
      wallpaperOverlay: wallpaperOverlay,
      panelOpacity: panelOpacity,
      panelBlurSigma: panelBlurSigma,
      sparkleIntensity: sparkleIntensity,
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
    String? backgroundFileName,
    bool clearBackgroundFileName = false,
    int? backgroundRevision,
    double? wallpaperOpacity,
    double? wallpaperOverlay,
    double? panelOpacity,
    double? panelBlurSigma,
    double? sparkleIntensity,
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
      backgroundFileName:
          clearBackgroundFileName
              ? null
              : backgroundFileName ?? this.backgroundFileName,
      backgroundRevision: backgroundRevision ?? this.backgroundRevision,
      wallpaperOpacity: _clamp(
        wallpaperOpacity ?? this.wallpaperOpacity,
        0.1,
        1,
      ),
      wallpaperOverlay: _clamp(
        wallpaperOverlay ?? this.wallpaperOverlay,
        0,
        0.85,
      ),
      panelOpacity: _clamp(panelOpacity ?? this.panelOpacity, 0.35, 1),
      panelBlurSigma: _clamp(panelBlurSigma ?? this.panelBlurSigma, 0, 30),
      sparkleIntensity: _clamp(sparkleIntensity ?? this.sparkleIntensity, 0, 2),
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
    'backgroundFileName': backgroundFileName,
    'backgroundRevision': backgroundRevision,
    'wallpaperOpacity': wallpaperOpacity,
    'wallpaperOverlay': wallpaperOverlay,
    'panelOpacity': panelOpacity,
    'panelBlurSigma': panelBlurSigma,
    'sparkleIntensity': sparkleIntensity,
  };

  factory ProjectAppearancePreferences.fromJson(Map<String, Object?> json) {
    final rawInheritsGlobal = json['inheritsGlobal'];
    final rawIconRevision = json['iconRevision'];
    final rawBackgroundRevision = json['backgroundRevision'];
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
      iconRevision:
          rawIconRevision is int
              ? rawIconRevision
              : int.tryParse(rawIconRevision?.toString() ?? '') ?? 0,
      backgroundFileName: _cleanOptionalText(json['backgroundFileName']),
      backgroundRevision:
          rawBackgroundRevision is int
              ? rawBackgroundRevision
              : int.tryParse(rawBackgroundRevision?.toString() ?? '') ?? 0,
      wallpaperOpacity: _readDouble(json['wallpaperOpacity'], 1, 0.1, 1),
      wallpaperOverlay: _readDouble(json['wallpaperOverlay'], 0.18, 0, 0.85),
      panelOpacity: _readDouble(json['panelOpacity'], 1, 0.35, 1),
      panelBlurSigma: _readDouble(json['panelBlurSigma'], 0, 0, 30),
      sparkleIntensity: _readDouble(json['sparkleIntensity'], 1, 0, 2),
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
            iconRevision == other.iconRevision &&
            backgroundFileName == other.backgroundFileName &&
            backgroundRevision == other.backgroundRevision &&
            wallpaperOpacity == other.wallpaperOpacity &&
            wallpaperOverlay == other.wallpaperOverlay &&
            panelOpacity == other.panelOpacity &&
            panelBlurSigma == other.panelBlurSigma &&
            sparkleIntensity == other.sparkleIntensity;
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
    backgroundFileName,
    backgroundRevision,
    wallpaperOpacity,
    wallpaperOverlay,
    panelOpacity,
    panelBlurSigma,
    sparkleIntensity,
  );
}

String? _cleanOptionalText(Object? raw) {
  final value = raw?.toString().trim();
  return value == null || value.isEmpty ? null : value;
}

double _readDouble(
  Object? raw,
  double fallback,
  double minimum,
  double maximum,
) {
  final value = raw is num ? raw.toDouble() : double.tryParse('$raw');
  return _clamp(value ?? fallback, minimum, maximum);
}

double _clamp(double value, double minimum, double maximum) {
  return value.clamp(minimum, maximum).toDouble();
}
