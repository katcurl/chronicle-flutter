import 'package:flutter/material.dart';

enum ChroniclePalette {
  violet(
    id: 'violet',
    label: 'Фиолетовая',
    seed: Color(0xFF7656C8),
    lightBackground: Color(0xFFF8F5FF),
    darkBackground: Color(0xFF141118),
    lightPanel: Color(0xFFFFFBFF),
    darkPanel: Color(0xFF211B28),
  ),
  orange(
    id: 'orange',
    label: 'Оранжевая',
    seed: Color(0xFFE66A1F),
    lightBackground: Color(0xFFFFF6EF),
    darkBackground: Color(0xFF1B120D),
    lightPanel: Color(0xFFFFFBF7),
    darkPanel: Color(0xFF2A1B13),
  ),
  amber(
    id: 'amber',
    label: 'Жёлтая',
    seed: Color(0xFFD99A00),
    lightBackground: Color(0xFFFFF9E8),
    darkBackground: Color(0xFF181409),
    lightPanel: Color(0xFFFFFDF4),
    darkPanel: Color(0xFF28210E),
  ),
  red(
    id: 'red',
    label: 'Красная',
    seed: Color(0xFFD94343),
    lightBackground: Color(0xFFFFF4F3),
    darkBackground: Color(0xFF1B1010),
    lightPanel: Color(0xFFFFFBFA),
    darkPanel: Color(0xFF2B1717),
  ),
  pink(
    id: 'pink',
    label: 'Розовая',
    seed: Color(0xFFD94C91),
    lightBackground: Color(0xFFFFF4F9),
    darkBackground: Color(0xFF1B1016),
    lightPanel: Color(0xFFFFFAFC),
    darkPanel: Color(0xFF2A1722),
  ),
  blue(
    id: 'blue',
    label: 'Синяя',
    seed: Color(0xFF3978D4),
    lightBackground: Color(0xFFF3F7FF),
    darkBackground: Color(0xFF0E141D),
    lightPanel: Color(0xFFFAFCFF),
    darkPanel: Color(0xFF172231),
  ),
  green(
    id: 'green',
    label: 'Зелёная',
    seed: Color(0xFF398B5B),
    lightBackground: Color(0xFFF1FAF4),
    darkBackground: Color(0xFF0D1711),
    lightPanel: Color(0xFFF9FEFA),
    darkPanel: Color(0xFF17271D),
  ),
  graphite(
    id: 'graphite',
    label: 'Графитовая',
    seed: Color(0xFF66717F),
    lightBackground: Color(0xFFF4F5F7),
    darkBackground: Color(0xFF111317),
    lightPanel: Color(0xFFFCFCFD),
    darkPanel: Color(0xFF1D2026),
  );

  const ChroniclePalette({
    required this.id,
    required this.label,
    required this.seed,
    required this.lightBackground,
    required this.darkBackground,
    required this.lightPanel,
    required this.darkPanel,
  });

  final String id;
  final String label;
  final Color seed;
  final Color lightBackground;
  final Color darkBackground;
  final Color lightPanel;
  final Color darkPanel;

  Color background(Brightness brightness) =>
      brightness == Brightness.light ? lightBackground : darkBackground;

  Color panel(Brightness brightness) =>
      brightness == Brightness.light ? lightPanel : darkPanel;

  static ChroniclePalette fromId(Object? raw, {ChroniclePalette? fallback}) {
    final id = raw?.toString();
    for (final palette in values) {
      if (palette.id == id) return palette;
    }
    return fallback ?? ChroniclePalette.violet;
  }
}

enum ChronicleSurfaceStyle {
  matte(
    id: 'matte',
    label: 'Матовый',
    description: 'Спокойные однотонные поверхности без бликов.',
  ),
  glossy(
    id: 'glossy',
    label: 'Glossy',
    description: 'Мягкий градиент, светлая кромка и лёгкий объём.',
  ),
  shiny(
    id: 'shiny',
    label: 'Shiny',
    description: 'Мелкие блёстки, сияющие точки и выразительный объём.',
  );

  const ChronicleSurfaceStyle({
    required this.id,
    required this.label,
    required this.description,
  });

  final String id;
  final String label;
  final String description;

  static ChronicleSurfaceStyle fromId(Object? raw) {
    final id = raw?.toString();
    for (final style in values) {
      if (style.id == id) return style;
    }
    return ChronicleSurfaceStyle.matte;
  }
}

enum ChronicleBrightnessMode {
  system(id: 'system', label: 'Как в системе'),
  light(id: 'light', label: 'Светлая'),
  dark(id: 'dark', label: 'Тёмная');

  const ChronicleBrightnessMode({required this.id, required this.label});

  final String id;
  final String label;

  ThemeMode get themeMode => switch (this) {
    ChronicleBrightnessMode.system => ThemeMode.system,
    ChronicleBrightnessMode.light => ThemeMode.light,
    ChronicleBrightnessMode.dark => ThemeMode.dark,
  };

  static ChronicleBrightnessMode fromId(Object? raw) {
    final id = raw?.toString();
    for (final mode in values) {
      if (mode.id == id) return mode;
    }
    return ChronicleBrightnessMode.system;
  }
}

class AppAppearancePreferences {
  const AppAppearancePreferences({
    required this.accentPalette,
    required this.iconPalette,
    required this.backgroundPalette,
    required this.panelPalette,
    required this.surfaceStyle,
    required this.brightnessMode,
    this.backgroundFileName,
    this.backgroundRevision = 0,
    this.wallpaperOpacity = 1,
    this.wallpaperOverlay = 0.18,
    this.panelOpacity = 1,
    this.panelBlurSigma = 0,
    this.sparkleIntensity = 1,
  });

  final ChroniclePalette accentPalette;
  final ChroniclePalette iconPalette;
  final ChroniclePalette backgroundPalette;
  final ChroniclePalette panelPalette;
  final ChronicleSurfaceStyle surfaceStyle;
  final ChronicleBrightnessMode brightnessMode;
  final String? backgroundFileName;
  final int backgroundRevision;
  final double wallpaperOpacity;
  final double wallpaperOverlay;
  final double panelOpacity;
  final double panelBlurSigma;
  final double sparkleIntensity;

  bool get hasBackgroundImage => backgroundFileName != null;

  factory AppAppearancePreferences.defaults() {
    return const AppAppearancePreferences(
      accentPalette: ChroniclePalette.violet,
      iconPalette: ChroniclePalette.violet,
      backgroundPalette: ChroniclePalette.violet,
      panelPalette: ChroniclePalette.violet,
      surfaceStyle: ChronicleSurfaceStyle.matte,
      brightnessMode: ChronicleBrightnessMode.system,
    );
  }

  factory AppAppearancePreferences.preset(
    ChroniclePalette palette, {
    ChronicleSurfaceStyle surfaceStyle = ChronicleSurfaceStyle.matte,
    ChronicleBrightnessMode brightnessMode = ChronicleBrightnessMode.system,
    String? backgroundFileName,
    int backgroundRevision = 0,
    double wallpaperOpacity = 1,
    double wallpaperOverlay = 0.18,
    double panelOpacity = 1,
    double panelBlurSigma = 0,
    double sparkleIntensity = 1,
  }) {
    return AppAppearancePreferences(
      accentPalette: palette,
      iconPalette: palette,
      backgroundPalette: palette,
      panelPalette: palette,
      surfaceStyle: surfaceStyle,
      brightnessMode: brightnessMode,
      backgroundFileName: backgroundFileName,
      backgroundRevision: backgroundRevision,
      wallpaperOpacity: wallpaperOpacity,
      wallpaperOverlay: wallpaperOverlay,
      panelOpacity: panelOpacity,
      panelBlurSigma: panelBlurSigma,
      sparkleIntensity: sparkleIntensity,
    );
  }

  bool get usesCoordinatedPalette =>
      accentPalette == iconPalette &&
      accentPalette == backgroundPalette &&
      accentPalette == panelPalette;

  AppAppearancePreferences copyWith({
    ChroniclePalette? accentPalette,
    ChroniclePalette? iconPalette,
    ChroniclePalette? backgroundPalette,
    ChroniclePalette? panelPalette,
    ChronicleSurfaceStyle? surfaceStyle,
    ChronicleBrightnessMode? brightnessMode,
    String? backgroundFileName,
    bool clearBackgroundFileName = false,
    int? backgroundRevision,
    double? wallpaperOpacity,
    double? wallpaperOverlay,
    double? panelOpacity,
    double? panelBlurSigma,
    double? sparkleIntensity,
  }) {
    return AppAppearancePreferences(
      accentPalette: accentPalette ?? this.accentPalette,
      iconPalette: iconPalette ?? this.iconPalette,
      backgroundPalette: backgroundPalette ?? this.backgroundPalette,
      panelPalette: panelPalette ?? this.panelPalette,
      surfaceStyle: surfaceStyle ?? this.surfaceStyle,
      brightnessMode: brightnessMode ?? this.brightnessMode,
      backgroundFileName: clearBackgroundFileName
          ? null
          : backgroundFileName ?? this.backgroundFileName,
      backgroundRevision: backgroundRevision ?? this.backgroundRevision,
      wallpaperOpacity: _clampDouble(
        wallpaperOpacity ?? this.wallpaperOpacity,
        0.1,
        1,
      ),
      wallpaperOverlay: _clampDouble(
        wallpaperOverlay ?? this.wallpaperOverlay,
        0,
        0.85,
      ),
      panelOpacity: _clampDouble(
        panelOpacity ?? this.panelOpacity,
        0.35,
        1,
      ),
      panelBlurSigma: _clampDouble(
        panelBlurSigma ?? this.panelBlurSigma,
        0,
        30,
      ),
      sparkleIntensity: _clampDouble(
        sparkleIntensity ?? this.sparkleIntensity,
        0,
        2,
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'accentPalette': accentPalette.id,
    'iconPalette': iconPalette.id,
    'backgroundPalette': backgroundPalette.id,
    'panelPalette': panelPalette.id,
    'surfaceStyle': surfaceStyle.id,
    'brightnessMode': brightnessMode.id,
    'backgroundFileName': backgroundFileName,
    'backgroundRevision': backgroundRevision,
    'wallpaperOpacity': wallpaperOpacity,
    'wallpaperOverlay': wallpaperOverlay,
    'panelOpacity': panelOpacity,
    'panelBlurSigma': panelBlurSigma,
    'sparkleIntensity': sparkleIntensity,
  };

  factory AppAppearancePreferences.fromJson(Map<String, Object?> json) {
    final rawRevision = json['backgroundRevision'];
    return AppAppearancePreferences(
      accentPalette: ChroniclePalette.fromId(json['accentPalette']),
      iconPalette: ChroniclePalette.fromId(
        json['iconPalette'],
        fallback: ChroniclePalette.fromId(json['accentPalette']),
      ),
      backgroundPalette: ChroniclePalette.fromId(
        json['backgroundPalette'],
        fallback: ChroniclePalette.graphite,
      ),
      panelPalette: ChroniclePalette.fromId(
        json['panelPalette'],
        fallback: ChroniclePalette.fromId(json['accentPalette']),
      ),
      surfaceStyle: ChronicleSurfaceStyle.fromId(json['surfaceStyle']),
      brightnessMode: ChronicleBrightnessMode.fromId(json['brightnessMode']),
      backgroundFileName: _cleanOptionalText(json['backgroundFileName']),
      backgroundRevision: rawRevision is int
          ? rawRevision
          : int.tryParse(rawRevision?.toString() ?? '') ?? 0,
      wallpaperOpacity: _readDouble(json['wallpaperOpacity'], 1, 0.1, 1),
      wallpaperOverlay: _readDouble(
        json['wallpaperOverlay'],
        0.18,
        0,
        0.85,
      ),
      panelOpacity: _readDouble(json['panelOpacity'], 1, 0.35, 1),
      panelBlurSigma: _readDouble(json['panelBlurSigma'], 0, 0, 30),
      sparkleIntensity: _readDouble(json['sparkleIntensity'], 1, 0, 2),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AppAppearancePreferences &&
            accentPalette == other.accentPalette &&
            iconPalette == other.iconPalette &&
            backgroundPalette == other.backgroundPalette &&
            panelPalette == other.panelPalette &&
            surfaceStyle == other.surfaceStyle &&
            brightnessMode == other.brightnessMode &&
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
    accentPalette,
    iconPalette,
    backgroundPalette,
    panelPalette,
    surfaceStyle,
    brightnessMode,
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
  return _clampDouble(value ?? fallback, minimum, maximum);
}

double _clampDouble(double value, double minimum, double maximum) {
  return value.clamp(minimum, maximum).toDouble();
}
