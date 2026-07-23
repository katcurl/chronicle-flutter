import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_appearance.dart';

ThemeData buildChronicleTheme(
  Brightness brightness,
  AppAppearancePreferences appearance, {
  bool backgroundAvailable = false,
}) {
  final isLight = brightness == Brightness.light;
  final background = appearance.backgroundPalette.background(brightness);
  final panel = appearance.panelPalette.panel(brightness);
  final accent = _adjustForBrightness(
    appearance.accentPalette.seed,
    brightness,
  );
  final iconAccent = _adjustForBrightness(
    appearance.iconPalette.seed,
    brightness,
  );
  final generated = ColorScheme.fromSeed(
    seedColor: appearance.accentPalette.seed,
    brightness: brightness,
  );
  final panelLow = Color.lerp(panel, background, isLight ? 0.18 : 0.12)!;
  final panelMid = Color.lerp(panel, accent, isLight ? 0.045 : 0.08)!;
  final panelHigh = Color.lerp(panel, accent, isLight ? 0.09 : 0.14)!;
  final panelHighest = Color.lerp(panel, accent, isLight ? 0.15 : 0.22)!;
  final outline =
      Color.lerp(
        generated.outlineVariant,
        appearance.panelPalette.seed,
        isLight ? 0.12 : 0.2,
      )!;
  final colors = generated.copyWith(
    primary: accent,
    surface: panel,
    surfaceContainerLowest: panel,
    surfaceContainerLow: panelLow,
    surfaceContainer: panelMid,
    surfaceContainerHigh: panelHigh,
    surfaceContainerHighest: panelHighest,
    outlineVariant: outline,
  );
  final style = appearance.surfaceStyle;
  final elevation = switch (style) {
    ChronicleSurfaceStyle.matte => 0.0,
    ChronicleSurfaceStyle.glossy => 1.0,
    ChronicleSurfaceStyle.shiny => 3.0,
  };
  final cardSide = switch (style) {
    ChronicleSurfaceStyle.matte => BorderSide.none,
    ChronicleSurfaceStyle.glossy => BorderSide(
      color: colors.outlineVariant.withValues(alpha: 0.72),
    ),
    ChronicleSurfaceStyle.shiny => BorderSide(
      color: _highlight(panel, brightness).withValues(alpha: 0.78),
    ),
  };

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor:
        backgroundAvailable ? Colors.transparent : background,
    visualDensity: VisualDensity.standard,
    iconTheme: IconThemeData(color: iconAccent),
    primaryIconTheme: IconThemeData(color: iconAccent),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: iconAccent),
      actionsIconTheme: IconThemeData(color: iconAccent),
      titleTextStyle: TextStyle(
        color: colors.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: elevation,
      margin: EdgeInsets.zero,
      shadowColor: colors.shadow.withValues(
        alpha: style == ChronicleSurfaceStyle.shiny ? 0.26 : 0.14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: cardSide,
      ),
      color: panelMid.withValues(alpha: appearance.panelOpacity),
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side:
            style == ChronicleSurfaceStyle.matte
                ? BorderSide.none
                : BorderSide(color: colors.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: panelHigh.withValues(alpha: appearance.panelOpacity),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: Colors.transparent,
      indicatorColor: colors.secondaryContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: iconAccent);
        }
        return IconThemeData(color: colors.onSurfaceVariant);
      }),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: colors.onSurface, fontWeight: FontWeight.w600),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: colors.secondaryContainer,
      selectedIconTheme: IconThemeData(color: iconAccent),
      selectedLabelTextStyle: TextStyle(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
      ),
      unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
      unselectedLabelTextStyle: TextStyle(color: colors.onSurfaceVariant),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: iconAccent,
      selectedColor: iconAccent,
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant),
    scrollbarTheme: ScrollbarThemeData(
      thumbVisibility: const WidgetStatePropertyAll(false),
      radius: const Radius.circular(99),
      thickness: const WidgetStatePropertyAll(6),
      thumbColor: WidgetStatePropertyAll(
        colors.onSurfaceVariant.withValues(alpha: 0.35),
      ),
    ),
    extensions: <ThemeExtension<dynamic>>[
      ChronicleAppearanceTheme(
        style: style,
        panelColor: panel,
        panelHighlight: _highlight(panel, brightness),
        panelShadow: _shadow(panel, brightness),
        iconAccent: iconAccent,
        outlineColor: colors.outlineVariant,
        backgroundColor: background,
        wallpaperOpacity: appearance.wallpaperOpacity,
        wallpaperOverlay: appearance.wallpaperOverlay,
        panelOpacity: appearance.panelOpacity,
        panelBlurSigma: appearance.panelBlurSigma,
        sparkleIntensity: appearance.sparkleIntensity,
      ),
    ],
  );
}

@immutable
class ChronicleAppearanceTheme
    extends ThemeExtension<ChronicleAppearanceTheme> {
  const ChronicleAppearanceTheme({
    required this.style,
    required this.panelColor,
    required this.panelHighlight,
    required this.panelShadow,
    required this.iconAccent,
    required this.outlineColor,
    required this.backgroundColor,
    required this.wallpaperOpacity,
    required this.wallpaperOverlay,
    required this.panelOpacity,
    required this.panelBlurSigma,
    required this.sparkleIntensity,
  });

  final ChronicleSurfaceStyle style;
  final Color panelColor;
  final Color panelHighlight;
  final Color panelShadow;
  final Color iconAccent;
  final Color outlineColor;
  final Color backgroundColor;
  final double wallpaperOpacity;
  final double wallpaperOverlay;
  final double panelOpacity;
  final double panelBlurSigma;
  final double sparkleIntensity;

  @override
  ChronicleAppearanceTheme copyWith({
    ChronicleSurfaceStyle? style,
    Color? panelColor,
    Color? panelHighlight,
    Color? panelShadow,
    Color? iconAccent,
    Color? outlineColor,
    Color? backgroundColor,
    double? wallpaperOpacity,
    double? wallpaperOverlay,
    double? panelOpacity,
    double? panelBlurSigma,
    double? sparkleIntensity,
  }) {
    return ChronicleAppearanceTheme(
      style: style ?? this.style,
      panelColor: panelColor ?? this.panelColor,
      panelHighlight: panelHighlight ?? this.panelHighlight,
      panelShadow: panelShadow ?? this.panelShadow,
      iconAccent: iconAccent ?? this.iconAccent,
      outlineColor: outlineColor ?? this.outlineColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      wallpaperOpacity: wallpaperOpacity ?? this.wallpaperOpacity,
      wallpaperOverlay: wallpaperOverlay ?? this.wallpaperOverlay,
      panelOpacity: panelOpacity ?? this.panelOpacity,
      panelBlurSigma: panelBlurSigma ?? this.panelBlurSigma,
      sparkleIntensity: sparkleIntensity ?? this.sparkleIntensity,
    );
  }

  @override
  ChronicleAppearanceTheme lerp(
    covariant ThemeExtension<ChronicleAppearanceTheme>? other,
    double t,
  ) {
    if (other is! ChronicleAppearanceTheme) return this;
    return ChronicleAppearanceTheme(
      style: t < 0.5 ? style : other.style,
      panelColor: Color.lerp(panelColor, other.panelColor, t)!,
      panelHighlight: Color.lerp(panelHighlight, other.panelHighlight, t)!,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t)!,
      iconAccent: Color.lerp(iconAccent, other.iconAccent, t)!,
      outlineColor: Color.lerp(outlineColor, other.outlineColor, t)!,
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t)!,
      wallpaperOpacity:
          lerpDouble(wallpaperOpacity, other.wallpaperOpacity, t)!,
      wallpaperOverlay:
          lerpDouble(wallpaperOverlay, other.wallpaperOverlay, t)!,
      panelOpacity: lerpDouble(panelOpacity, other.panelOpacity, t)!,
      panelBlurSigma: lerpDouble(panelBlurSigma, other.panelBlurSigma, t)!,
      sparkleIntensity:
          lerpDouble(sparkleIntensity, other.sparkleIntensity, t)!,
    );
  }

  BoxDecoration decoration({
    BorderRadiusGeometry? borderRadius,
    bool emphasized = false,
  }) {
    final radius = borderRadius ?? BorderRadius.zero;
    final panel = panelColor.withValues(alpha: panelOpacity);
    final highlight = panelHighlight.withValues(alpha: panelOpacity);
    final shadow = panelShadow.withValues(alpha: panelOpacity);
    switch (style) {
      case ChronicleSurfaceStyle.matte:
        return BoxDecoration(color: panel, borderRadius: radius);
      case ChronicleSurfaceStyle.glossy:
        return BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color.lerp(highlight, panel, 0.22)!, panel],
          ),
          border: Border.all(
            color: panelHighlight.withValues(alpha: 0.62 * panelOpacity),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: panelShadow.withValues(alpha: emphasized ? 0.24 : 0.14),
              blurRadius: emphasized ? 22 : 14,
              offset: const Offset(0, 5),
            ),
          ],
        );
      case ChronicleSurfaceStyle.shiny:
        return BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const <double>[0, 0.34, 1],
            colors: <Color>[
              highlight,
              Color.lerp(highlight, panel, 0.68)!,
              shadow,
            ],
          ),
          border: Border.all(
            color: panelHighlight.withValues(alpha: 0.82 * panelOpacity),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: panelShadow.withValues(alpha: emphasized ? 0.34 : 0.24),
              blurRadius: emphasized ? 28 : 18,
              offset: const Offset(0, 7),
            ),
          ],
        );
    }
  }
}

class ChroniclePanelSurface extends StatelessWidget {
  const ChroniclePanelSurface({
    super.key,
    required this.child,
    this.borderRadius,
    this.emphasized = false,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final BorderRadiusGeometry? borderRadius;
  final bool emphasized;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final appearance = Theme.of(context).extension<ChronicleAppearanceTheme>();
    if (appearance == null) return child;
    final radius = borderRadius ?? BorderRadius.zero;
    Widget content = Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        child,
        if (appearance.style == ChronicleSurfaceStyle.shiny &&
            appearance.sparkleIntensity > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ChronicleGlitterPainter(
                  sparkleColor: appearance.panelHighlight,
                  accentColor: appearance.iconAccent,
                  emphasized: emphasized,
                  intensity: appearance.sparkleIntensity,
                ),
              ),
            ),
          ),
      ],
    );
    if (appearance.panelBlurSigma > 0 && appearance.panelOpacity < 0.999) {
      content = BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: appearance.panelBlurSigma,
          sigmaY: appearance.panelBlurSigma,
        ),
        child: content,
      );
    }
    return DecoratedBox(
      decoration: appearance.decoration(
        borderRadius: radius,
        emphasized: emphasized,
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: content,
      ),
    );
  }
}

class ChronicleBackdrop extends StatelessWidget {
  const ChronicleBackdrop({
    super.key,
    required this.child,
    this.backgroundImage,
    this.revision = 0,
  });

  final Widget child;
  final ImageProvider<Object>? backgroundImage;
  final int revision;

  @override
  Widget build(BuildContext context) {
    final appearance = Theme.of(context).extension<ChronicleAppearanceTheme>();
    if (appearance == null || backgroundImage == null) return child;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ColoredBox(color: appearance.backgroundColor),
        Image(
          key: ValueKey<int>(revision),
          image: backgroundImage!,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          opacity: AlwaysStoppedAnimation<double>(appearance.wallpaperOpacity),
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const SizedBox.expand(),
        ),
        if (appearance.wallpaperOverlay > 0)
          ColoredBox(
            color: appearance.backgroundColor.withValues(
              alpha: appearance.wallpaperOverlay,
            ),
          ),
        child,
      ],
    );
  }
}

class _ChronicleGlitterPainter extends CustomPainter {
  const _ChronicleGlitterPainter({
    required this.sparkleColor,
    required this.accentColor,
    required this.emphasized,
    required this.intensity,
  });

  final Color sparkleColor;
  final Color accentColor;
  final bool emphasized;
  final double intensity;

  static const List<Offset> _points = <Offset>[
    Offset(0.07, 0.18),
    Offset(0.16, 0.72),
    Offset(0.24, 0.34),
    Offset(0.33, 0.84),
    Offset(0.42, 0.13),
    Offset(0.51, 0.58),
    Offset(0.61, 0.27),
    Offset(0.69, 0.77),
    Offset(0.78, 0.42),
    Offset(0.88, 0.16),
    Offset(0.94, 0.67),
    Offset(0.13, 0.44),
    Offset(0.37, 0.49),
    Offset(0.57, 0.89),
    Offset(0.83, 0.88),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint =
        Paint()
          ..color = sparkleColor.withValues(
            alpha:
                ((emphasized ? 0.52 : 0.34) * intensity).clamp(0, 1).toDouble(),
          )
          ..style = PaintingStyle.fill;
    final accentPaint =
        Paint()
          ..color = accentColor.withValues(
            alpha:
                ((emphasized ? 0.42 : 0.26) * intensity).clamp(0, 1).toDouble(),
          )
          ..strokeWidth = emphasized ? 1.2 : 0.9
          ..strokeCap = StrokeCap.round;

    for (var index = 0; index < _points.length; index++) {
      final normalized = _points[index];
      final center = Offset(
        normalized.dx * size.width,
        normalized.dy * size.height,
      );
      final radius = (index % 3 == 0 ? 1.45 : 0.8) * (0.72 + intensity * 0.28);
      canvas.drawCircle(center, radius, dotPaint);
      if (index % 4 == 0) {
        final arm = (emphasized ? 4.0 : 3.0) * (0.72 + intensity * 0.28);
        canvas.drawLine(
          center.translate(-arm, 0),
          center.translate(arm, 0),
          accentPaint,
        );
        canvas.drawLine(
          center.translate(0, -arm),
          center.translate(0, arm),
          accentPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChronicleGlitterPainter oldDelegate) {
    return sparkleColor != oldDelegate.sparkleColor ||
        accentColor != oldDelegate.accentColor ||
        emphasized != oldDelegate.emphasized ||
        intensity != oldDelegate.intensity;
  }
}

Color _adjustForBrightness(Color color, Brightness brightness) {
  return brightness == Brightness.light
      ? Color.lerp(color, Colors.black, 0.04)!
      : Color.lerp(color, Colors.white, 0.2)!;
}

Color _highlight(Color panel, Brightness brightness) {
  return Color.lerp(
    panel,
    Colors.white,
    brightness == Brightness.light ? 0.72 : 0.18,
  )!;
}

Color _shadow(Color panel, Brightness brightness) {
  return Color.lerp(
    panel,
    Colors.black,
    brightness == Brightness.light ? 0.13 : 0.34,
  )!;
}
